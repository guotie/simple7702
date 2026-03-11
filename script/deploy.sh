#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOY_SCRIPT="script/Deploy.s.sol"
SUPPORTED_CHAINS="amoy"

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

load_env() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local env_file="$script_dir/.env"

    if [ -f "$env_file" ]; then
        set -a
        source "$env_file"
        set +a
        print_info "Loaded environment from $env_file"
    fi
}

get_rpc_var_name() {
    local chain=$1
    case "$chain" in
        "amoy") echo "POLYGON_AMOY_RPC_URL" ;;
        *) echo "" ;;
    esac
}

get_chain_id() {
    local chain=$1
    case "$chain" in
        "amoy") echo "80002" ;;
        *) echo "" ;;
    esac
}

get_explorer_var_name() {
    local chain=$1
    case "$chain" in
        "amoy") echo "POLYGONSCAN_API_KEY" ;;
        *) echo "" ;;
    esac
}

get_rpc_url() {
    local chain=$1
    local rpc_var=$(get_rpc_var_name "$chain")

    if [ -z "$rpc_var" ]; then
        print_error "Unknown chain: $chain"
        return 1
    fi

    local rpc_url=$(eval echo "\$$rpc_var")
    if [ -z "$rpc_url" ]; then
        print_error "RPC URL not set for $chain (set $rpc_var)"
        return 1
    fi

    echo "$rpc_url"
}

get_explorer_key() {
    local chain=$1
    local key_var=$(get_explorer_var_name "$chain")
    if [ -z "$key_var" ]; then
        echo ""
        return
    fi
    echo "$(eval echo "\$$key_var")"
}

check_prerequisites() {
    if ! command -v forge >/dev/null 2>&1; then
        print_error "forge is not installed"
        exit 1
    fi

    if ! command -v cast >/dev/null 2>&1; then
        print_error "cast is not installed"
        exit 1
    fi
}

cmd_preview() {
    local chain=$1
    if [ -z "$chain" ]; then
        print_error "Please specify a chain"
        echo "Available chains: $SUPPORTED_CHAINS"
        exit 1
    fi

    local rpc_url=$(get_rpc_url "$chain")
    if [ $? -ne 0 ]; then
        exit 1
    fi

    print_header "Preview Deployment - $chain"

    local sender_arg=""
    if [ -n "$PRIVATE_KEY" ]; then
        local sender=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null)
        if [ -n "$sender" ]; then
            sender_arg="--sender $sender"
        fi
    elif [ -n "$DEPLOYER_ADDRESS" ]; then
        sender_arg="--sender $DEPLOYER_ADDRESS"
    fi

    forge script "$DEPLOY_SCRIPT" \
        --sig "preview()" \
        --rpc-url "$rpc_url" \
        $sender_arg \
        -vvv
}

cmd_deploy() {
    local chain=$1
    if [ -z "$chain" ]; then
        print_error "Please specify a chain"
        echo "Available chains: $SUPPORTED_CHAINS"
        exit 1
    fi

    if [ -z "$PRIVATE_KEY" ]; then
        print_error "PRIVATE_KEY environment variable is required"
        exit 1
    fi

    local rpc_url=$(get_rpc_url "$chain")
    if [ $? -ne 0 ]; then
        exit 1
    fi

    local explorer_key=$(get_explorer_key "$chain")
    local verify_flag=""
    if [ -n "$explorer_key" ]; then
        verify_flag="--verify --etherscan-api-key $explorer_key"
    else
        print_warning "No explorer API key found, skipping verification"
    fi

    print_header "Deploying to $chain"

    forge script "$DEPLOY_SCRIPT" \
        --rpc-url "$rpc_url" \
        --broadcast \
        --private-key "$PRIVATE_KEY" \
        $verify_flag \
        -vvvv

    print_success "Deployment to $chain completed"
}

cmd_verify() {
    local chain=$1
    local contract=$2
    local address=$3

    if [ -z "$chain" ] || [ -z "$contract" ] || [ -z "$address" ]; then
        print_error "Usage: $0 verify <chain> <contract> <address> [constructor args]"
        echo "Contracts: Simple7702PolicyRegistry, Simple7702Account"
        exit 1
    fi

    local chain_id=$(get_chain_id "$chain")
    local explorer_key=$(get_explorer_key "$chain")

    if [ -z "$chain_id" ] || [ -z "$explorer_key" ]; then
        print_error "Missing chain id or explorer API key for $chain"
        exit 1
    fi

    print_header "Verifying $contract on $chain"

    case "$contract" in
        "Simple7702PolicyRegistry")
            if [ -z "$4" ]; then
                print_error "Simple7702PolicyRegistry requires: <owner>"
                exit 1
            fi
            forge verify-contract \
                --chain-id "$chain_id" \
                --etherscan-api-key "$explorer_key" \
                "$address" \
                src/Simple7702PolicyRegistry.sol:Simple7702PolicyRegistry \
                --constructor-args "$(cast abi-encode "constructor(address)" "$4")"
            ;;
        "Simple7702Account")
            if [ -z "$4" ]; then
                print_error "Simple7702Account requires: <registry>"
                exit 1
            fi
            forge verify-contract \
                --chain-id "$chain_id" \
                --etherscan-api-key "$explorer_key" \
                "$address" \
                src/Simple7702Account.sol:Simple7702Account \
                --constructor-args "$(cast abi-encode "constructor(address)" "$4")"
            ;;
        *)
            print_error "Unknown contract: $contract"
            exit 1
            ;;
    esac
}

main() {
    load_env
    check_prerequisites

    local command=$1
    shift || true

    case "$command" in
        "preview")
            cmd_preview "$@"
            ;;
        "deploy")
            cmd_deploy "$@"
            ;;
        "verify")
            cmd_verify "$@"
            ;;
        *)
            echo "Usage: $0 <command> [chain]"
            echo "Commands:"
            echo "  preview  Preview deployment addresses"
            echo "  deploy   Deploy contracts"
            echo "  verify   Verify a deployed contract"
            echo "Available chains: $SUPPORTED_CHAINS"
            exit 1
            ;;
    esac
}

main "$@"
