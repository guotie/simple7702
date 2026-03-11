#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOY_SCRIPT="script/DeployUniversal.s.sol"

# Supported chains: mainnet, testnet
SUPPORTED_CHAINS="mainnet arbitrum optimism base polygon bsc avalanche fantom gnosis scroll zksync linea mantle basegoerli sepolia amoy"

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
        "mainnet")      echo "MAINNET_RPC_URL" ;;
        "arbitrum")     echo "ARBITRUM_RPC_URL" ;;
        "optimism")     echo "OPTIMISM_RPC_URL" ;;
        "base")         echo "BASE_RPC_URL" ;;
        "polygon")      echo "POLYGON_RPC_URL" ;;
        "bsc")          echo "BSC_RPC_URL" ;;
        "avalanche")    echo "AVALANCHE_RPC_URL" ;;
        "fantom")       echo "FANTOM_RPC_URL" ;;
        "gnosis")       echo "GNOSIS_RPC_URL" ;;
        "scroll")       echo "SCROLL_RPC_URL" ;;
        "zksync")       echo "ZKSYNC_RPC_URL" ;;
        "linea")        echo "LINEA_RPC_URL" ;;
        "mantle")       echo "MANTLE_RPC_URL" ;;
        "basegoerli")   echo "BASE_GOERLI_RPC_URL" ;;
        "sepolia")      echo "SEPOLIA_RPC_URL" ;;
        "amoy")         echo "POLYGON_AMOY_RPC_URL" ;;
        *) echo "" ;;
    esac
}

get_chain_id() {
    local chain=$1
    case "$chain" in
        "mainnet")      echo "1" ;;
        "arbitrum")     echo "42161" ;;
        "optimism")     echo "10" ;;
        "base")         echo "8453" ;;
        "polygon")      echo "137" ;;
        "bsc")          echo "56" ;;
        "avalanche")    echo "43114" ;;
        "fantom")       echo "250" ;;
        "gnosis")       echo "100" ;;
        "scroll")       echo "534352" ;;
        "zksync")       echo "324" ;;
        "linea")        echo "59144" ;;
        "mantle")       echo "5000" ;;
        "basegoerli")   echo "84531" ;;
        "sepolia")      echo "11155111" ;;
        "amoy")         echo "80002" ;;
        *) echo "" ;;
    esac
}

get_explorer_var_name() {
    local chain=$1
    case "$chain" in
        "mainnet")      echo "ETHERSCAN_API_KEY" ;;
        "arbitrum")     echo "ARBISCAN_API_KEY" ;;
        "optimism")     echo "OPTIMISTIC_ETHERSCAN_API_KEY" ;;
        "base")         echo "BASESCAN_API_KEY" ;;
        "polygon")      echo "POLYGONSCAN_API_KEY" ;;
        "bsc")          echo "BSCSCAN_API_KEY" ;;
        "avalanche")    echo "SNOWTRACE_API_KEY" ;;
        "fantom")       echo "FTMSCAN_API_KEY" ;;
        "gnosis")       echo "GNOSISSCAN_API_KEY" ;;
        "scroll")       echo "SCROLLSCAN_API_KEY" ;;
        "zksync")       echo "ZKSYNC_ETHERSCAN_API_KEY" ;;
        "linea")        echo "LINEASCAN_API_KEY" ;;
        "mantle")       echo "MANTLESCAN_API_KEY" ;;
        "basegoerli")   echo "BASESCAN_API_KEY" ;;
        "sepolia")      echo "ETHERSCAN_API_KEY" ;;
        "amoy")         echo "POLYGONSCAN_API_KEY" ;;
        *) echo "" ;;
    esac
}

get_explorer_url() {
    local chain=$1
    case "$chain" in
        "mainnet")      echo "https://etherscan.io" ;;
        "arbitrum")     echo "https://arbiscan.io" ;;
        "optimism")     echo "https://optimistic.etherscan.io" ;;
        "base")         echo "https://basescan.org" ;;
        "polygon")      echo "https://polygonscan.com" ;;
        "bsc")          echo "https://bscscan.com" ;;
        "avalanche")    echo "https://snowtrace.io" ;;
        "fantom")       echo "https://ftmscan.com" ;;
        "gnosis")       echo "https://gnosisscan.io" ;;
        "scroll")       echo "https://scrollscan.com" ;;
        "zksync")       echo "https://explorer.zksync.io" ;;
        "linea")        echo "https://lineascan.build" ;;
        "mantle")       echo "https://mantlescan.xyz" ;;
        "basegoerli")   echo "https://goerli.basescan.org" ;;
        "sepolia")      echo "https://sepolia.etherscan.io" ;;
        "amoy")         echo "https://amoy.polygonscan.com" ;;
        *) echo "" ;;
    esac
}

get_chain_name() {
    local chain=$1
    case "$chain" in
        "mainnet")      echo "Ethereum Mainnet" ;;
        "arbitrum")     echo "Arbitrum One" ;;
        "optimism")     echo "Optimism" ;;
        "base")         echo "Base" ;;
        "polygon")      echo "Polygon" ;;
        "bsc")          echo "BNB Smart Chain" ;;
        "avalanche")    echo "Avalanche C-Chain" ;;
        "fantom")       echo "Fantom Opera" ;;
        "gnosis")       echo "Gnosis Chain" ;;
        "scroll")       echo "Scroll" ;;
        "zksync")       echo "zkSync Era" ;;
        "linea")        echo "Linea" ;;
        "mantle")       echo "Mantle" ;;
        "basegoerli")   echo "Base Goerli" ;;
        "sepolia")      echo "Sepolia" ;;
        "amoy")         echo "Polygon Amoy" ;;
        *) echo "$chain" ;;
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

cmd_list() {
    print_header "Supported Chains"
    echo ""
    printf "%-15s %-20s %-10s\n" "Chain" "Name" "Chain ID"
    printf "%-15s %-20s %-10s\n" "-----" "----" "--------"
    
    for chain in $SUPPORTED_CHAINS; do
        local name=$(get_chain_name "$chain")
        local id=$(get_chain_id "$chain")
        printf "%-15s %-20s %-10s\n" "$chain" "$name" "$id"
    done
    echo ""
    echo "Usage: $0 <command> <chain>"
    echo "Commands: preview, deploy, verify"
}

cmd_preview() {
    local chain=$1
    if [ -z "$chain" ]; then
        print_error "Please specify a chain"
        echo "Available chains: $SUPPORTED_CHAINS"
        echo "Run '$0 list' for detailed chain info"
        exit 1
    fi

    local rpc_url=$(get_rpc_url "$chain")
    if [ $? -ne 0 ]; then
        exit 1
    fi

    local chain_name=$(get_chain_name "$chain")
    print_header "Preview Deployment - $chain_name"

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
        echo "Run '$0 list' for detailed chain info"
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

    local chain_name=$(get_chain_name "$chain")
    local explorer_key=$(get_explorer_key "$chain")
    local verify_flag=""
    if [ -n "$explorer_key" ]; then
        verify_flag="--verify --etherscan-api-key $explorer_key"
    else
        print_warning "No explorer API key found, skipping verification"
    fi

    print_header "Deploying Universal7702Account to $chain_name"

    forge script "$DEPLOY_SCRIPT" \
        --rpc-url "$rpc_url" \
        --broadcast \
        --private-key "$PRIVATE_KEY" \
        $verify_flag \
        -vvvv

    print_success "Deployment to $chain_name completed"
}

cmd_verify() {
    local chain=$1
    local address=$2

    if [ -z "$chain" ] || [ -z "$address" ]; then
        print_error "Usage: $0 verify <chain> <address>"
        echo "Example: $0 verify mainnet 0x1234...5678"
        exit 1
    fi

    local chain_id=$(get_chain_id "$chain")
    local explorer_key=$(get_explorer_key "$chain")
    local chain_name=$(get_chain_name "$chain")

    if [ -z "$chain_id" ]; then
        print_error "Unknown chain: $chain"
        exit 1
    fi

    if [ -z "$explorer_key" ]; then
        print_error "No explorer API key found for $chain_name"
        echo "Set $(get_explorer_var_name "$chain") environment variable"
        exit 1
    fi

    print_header "Verifying Universal7702Account on $chain_name"

    forge verify-contract \
        --chain-id "$chain_id" \
        --etherscan-api-key "$explorer_key" \
        "$address" \
        src/Universal7702Account.sol:Universal7702Account

    print_success "Verification submitted"
    local explorer_url=$(get_explorer_url "$chain")
    print_info "Check status at: $explorer_url/address/$address#code"
}

cmd_address() {
    print_header "Deterministic Deployment Address"
    
    # Compute the deterministic address (same across all chains)
    forge script "$DEPLOY_SCRIPT" \
        --sig "computeAddress()" \
        -vvv
}

main() {
    load_env
    check_prerequisites

    local command=$1
    shift || true

    case "$command" in
        "list")
            cmd_list
            ;;
        "preview")
            cmd_preview "$@"
            ;;
        "deploy")
            cmd_deploy "$@"
            ;;
        "verify")
            cmd_verify "$@"
            ;;
        "address")
            cmd_address
            ;;
        *)
            echo "Usage: $0 <command> [chain]"
            echo ""
            echo "Commands:"
            echo "  list      List all supported chains"
            echo "  preview   Preview deployment addresses"
            echo "  deploy    Deploy Universal7702Account"
            echo "  verify    Verify a deployed contract"
            echo "  address   Show deterministic deployment address"
            echo ""
            echo "Examples:"
            echo "  $0 list"
            echo "  $0 preview mainnet"
            echo "  $0 deploy arbitrum"
            echo "  $0 verify optimism 0x1234...5678"
            echo "  $0 address"
            exit 1
            ;;
    esac
}

main "$@"
