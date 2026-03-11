# Simple7702

The simplest way to use EIP-7702. No Paymaster, no Bundler, no complex infrastructure required.

## Why Simple7702?

Current EIP-7702 solutions are built on top of ERC-4337, requiring a complex stack:

| Component | ERC-4337 Stack | Simple7702 |
|-----------|---------------|------------|
| Paymaster | ❌ Required | ✅ Not needed |
| Bundler | ❌ Required | ✅ Not needed |
| EntryPoint Contract | ❌ Required | ✅ Not needed |
| UserOp Mempool | ❌ Required | ✅ Not needed |
| Infrastructure Cost | High | Minimal |
| Setup Complexity | High | Low |

**Simple7702 strips away the complexity.** Just deploy and you're ready to sponsor transactions.

## Two Implementations

This project provides two EIP-7702 account implementations:

### Simple7702Account

A policy-controlled 7702 delegate with whitelist management for sponsors and targets.

**Features:**
- ✅ **Policy Registry** - Control who can sponsor transactions and what contracts can be called
- ✅ **Sponsor Whitelist** - Restrict who can execute actions on behalf of users
- ✅ **Target Whitelist** - Restrict what contracts can be called
- ✅ **Bitmap Nonces** - Allows parallel execution with different nonces
- ✅ **EIP-712 Signatures** - Human-readable, secure signing

### Universal7702Account

A universal, permissionless 7702 delegate that anyone can relay signed actions.

**Features:**
- ✅ **No Registry Required** - Single contract deployment, no additional infrastructure
- ✅ **Permissionless Execution** - Anyone can execute actions on behalf of users
- ✅ **Sequential Nonces** - Simpler nonce management
- ✅ **EIP-712 Signatures** - Human-readable, secure signing
- ✅ **Lower Gas Cost** - No registry checks during execution

## Comparison: Simple7702Account vs Universal7702Account

| Feature | Simple7702Account | Universal7702Account |
|---------|-------------------|----------------------|
| **Registry Required** | ✅ Yes | ❌ No |
| **Sponsor Whitelist** | ✅ Supported | ❌ Not supported |
| **Target Whitelist** | ✅ Supported | ❌ Not supported |
| **Nonce Type** | Bitmap (parallel) | Sequential |
| **Deployment Complexity** | 2 contracts | 1 contract |
| **Gas Overhead** | Higher (registry checks) | Lower |
| **Permission Model** | Controlled | Permissionless |

### When to Use Simple7702Account

✅ **Recommended for:**
- Enterprise applications requiring access control
- DApps that need to restrict who can sponsor transactions
- Applications with compliance requirements
- Scenarios where you want to limit callable contracts
- Multi-tenant platforms with different sponsor policies

**Example Use Case:** A DeFi protocol wants to sponsor user transactions but only through their approved relayers and only for their approved contracts.

### When to Use Universal7702Account

✅ **Recommended for:**
- Open, permissionless applications
- Quick EIP-7702 integration without infrastructure
- Gas-sensitive applications
- Simple meta-transaction needs
- Protocols that want anyone to be able to relay

**Example Use Case:** A public goods project wants to allow any relayer to sponsor user transactions without maintaining a whitelist.

## The Problem with ERC-4337 Stack

Building on EIP-7702 + ERC-4337 means:

1. **Run a Paymaster** - Handle deposit management, gas estimation, sponsorship logic
2. **Run a Bundler** - Aggregate UserOps, simulate, submit to EntryPoint
3. **Deploy EntryPoint** - Another contract to manage, upgrade, secure
4. **Monitor Mempool** - Track UserOps, handle replacements, timeouts
5. **Complex Integration** - Client-side UserOp construction, signature schemes

This is overkill for many use cases. **Simple7702 provides a simpler alternative.**

## How It Works

### Simple7702Account Flow

```
┌─────────────┐                    ┌──────────────────────┐
│    User     │                    │   Simple7702Account  │
│   (EOA)     │                    │   (EIP-7702 Code)    │
└──────┬──────┘                    └──────────┬───────────┘
       │                                      │
       │  1. Sign Action (off-chain)          │
       │─────────────────────────────────────►│
       │                                      │
       │                                      │
┌──────▼──────┐                    ┌──────────▼───────────┐
│   Sponsor   │                    │   Policy Registry    │
│  (Relayer)  │                    │   (Whitelist Ctrl)   │
└──────┬──────┘                    └──────────────────────┘
       │
       │  2. Execute Action (pays gas)
       │─────────────────────────────────────►
       │                                      │
       ▼                                      ▼
```

### Universal7702Account Flow

```
┌─────────────┐                    ┌──────────────────────┐
│    User     │                    │  Universal7702Account│
│   (EOA)     │                    │   (EIP-7702 Code)    │
└──────┬──────┘                    └──────────┬───────────┘
       │                                      │
       │  1. Sign Action (off-chain)          │
       │─────────────────────────────────────►│
       │                                      │
       │                                      │
┌──────▼──────┐                              │
│    Any      │                              │
│  Relayer    │                              │
└──────┬──────┘                              │
       │                                      │
       │  2. Execute Action (pays gas)        │
       │─────────────────────────────────────►│
       │                                      │
       ▼                                      ▼
```

**Three simple steps:**

1. **User signs an action** - Off-chain, no gas required
2. **Relayer submits the action** - Pays gas on behalf of user
3. **Contract verifies and executes** - Signature + policy check (Simple7702) or just signature check (Universal7702)

That's it. No middleware, no additional services.

## Quick Start

### 1. Deploy

```bash
# Clone and build
git clone https://github.com/your-org/simple7702.git
cd simple7702
forge build

# Deploy Simple7702Account (with policy registry)
./script/deploy.sh deploy amoy

# OR Deploy Universal7702Account (single contract)
./script/deploy_universal.sh deploy amoy
```

### 2. Set Up Policy (Simple7702Account Only)

```solidity
// Whitelist your relayer
registry.setSponsorWhitelist(relayerAddress, true);

// Or whitelist allowed targets
registry.setTargetWhitelist(uniswapRouter, true);
```

### 3. Sponsor a Transaction

```javascript
// User signs (off-chain, no gas)
const action = {
    target: tokenAddress,
    value: 0,
    data: encodeTransfer(recipient, amount),
    nonce: 1,
    deadline: Math.floor(Date.now() / 1000) + 3600,
    executor: relayerAddress
};

const signature = await user.signTypedData(domain, types, action);

// Relayer executes (pays gas)
await account.execute(action, signature);
```

Done. No Paymaster deposit management. No bundler infrastructure.

## Features

### Core Capabilities

- ✅ **Sponsored Transactions** - Anyone can pay gas for user actions
- ✅ **EIP-712 Signatures** - Human-readable, secure signing
- ✅ **Batch Execution** - Multiple actions in one transaction
- ✅ **Policy Controls** - Whitelist sponsors and/or targets (Simple7702Account)

### Security Features

- ✅ **Signature Verification** - EIP-712 with low-s enforcement
- ✅ **Nonce Protection** - Replay prevention (bitmap or sequential)
- ✅ **Reentrancy Guard** - Protection against nested calls
- ✅ **Deadline Enforcement** - Actions expire after deadline

### Gas Optimized

- ✅ **Assembly Hashing** - EIP-712 digest computed in assembly
- ✅ **Cached Constants** - Pre-computed name/version hashes
- ✅ **Bitmap Nonces** - O(1) storage reads (Simple7702Account)

## Supported Chains

The deployment scripts support the following EVM chains:

### Mainnets
| Chain | Chain ID | RPC Env Variable |
|-------|----------|------------------|
| Ethereum | 1 | `MAINNET_RPC_URL` |
| Arbitrum | 42161 | `ARBITRUM_RPC_URL` |
| Optimism | 10 | `OPTIMISM_RPC_URL` |
| Base | 8453 | `BASE_RPC_URL` |
| Polygon | 137 | `POLYGON_RPC_URL` |
| BSC | 56 | `BSC_RPC_URL` |
| Avalanche | 43114 | `AVALANCHE_RPC_URL` |
| Fantom | 250 | `FANTOM_RPC_URL` |
| Gnosis | 100 | `GNOSIS_RPC_URL` |
| Scroll | 534352 | `SCROLL_RPC_URL` |
| zkSync | 324 | `ZKSYNC_RPC_URL` |
| Linea | 59144 | `LINEA_RPC_URL` |
| Mantle | 5000 | `MANTLE_RPC_URL` |

### Testnets
| Chain | Chain ID | RPC Env Variable |
|-------|----------|------------------|
| Sepolia | 11155111 | `SEPOLIA_RPC_URL` |
| Base Goerli | 84531 | `BASE_GOERLI_RPC_URL` |
| Polygon Amoy | 80002 | `POLYGON_AMOY_RPC_URL` |

## Deployment

### Simple7702Account

```bash
# List supported chains
./script/deploy.sh

# Preview deployment
./script/deploy.sh preview amoy

# Deploy
./script/deploy.sh deploy amoy

# Verify contract
./script/deploy.sh verify amoy Simple7702Account <address> <registry>
```

### Universal7702Account

```bash
# List supported chains
./script/deploy_universal.sh list

# Preview deployment
./script/deploy_universal.sh preview mainnet

# Deploy (uses CREATE2 for deterministic address)
./script/deploy_universal.sh deploy arbitrum

# Verify contract
./script/deploy_universal.sh verify optimism <address>

# Show deterministic deployment address (same across all chains)
./script/deploy_universal.sh address
```

## Comparison

### Simple7702 vs ERC-4337 Stack

| Aspect | ERC-4337 Stack | Simple7702 |
|--------|---------------|------------|
| **Setup Time** | Days to weeks | Minutes |
| **Infrastructure** | Paymaster + Bundler + EntryPoint | 1-2 contracts |
| **Maintenance** | High (multiple services) | Low (just contracts) |
| **Gas Overhead** | Higher (EntryPoint logic) | Lower (direct execution) |
| **Complexity** | High (UserOp, mempool) | Low (simple signature) |
| **Flexibility** | Constrained by EntryPoint | Full control |

## Architecture

### Contracts

| Contract | Lines | Description |
|----------|-------|-------------|
| [`Simple7702Account`](src/Simple7702Account.sol) | ~230 | Policy-controlled delegate contract |
| [`Simple7702PolicyRegistry`](src/Simple7702PolicyRegistry.sol) | ~80 | Whitelist management |
| [`Universal7702Account`](src/Universal7702Account.sol) | ~190 | Universal permissionless delegate |

### Action Structure

```solidity
struct Action {
    address target;    // Who to call
    uint256 value;     // ETH to send
    bytes data;        // What to call
    uint256 nonce;     // Replay protection
    uint256 deadline;  // When it expires
    address executor;  // Who can execute
}
```

## Usage Examples

### Basic Sponsored Transfer

```javascript
// User wants to transfer tokens but has no ETH
const action = {
    target: usdcAddress,
    value: 0,
    data: usdc.interface.encodeFunctionData('transfer', [recipient, amount]),
    nonce: 1,
    deadline: deadline,
    executor: sponsorAddress
};

// User signs (no gas needed)
const signature = await user.signTypedData(domain, types, action);

// Sponsor pays gas and executes
await account.connect(sponsor).execute(action, signature);
```

### Batch Operations

```javascript
// Approve + swap in one sponsored transaction
const actions = [
    {
        target: usdcAddress,
        data: usdc.interface.encodeFunctionData('approve', [router, amount]),
        // ... other fields
    },
    {
        target: routerAddress,
        data: router.interface.encodeFunctionData('swapExactTokensForETH', [...]),
        // ... other fields
    }
];

const signatures = await Promise.all(
    actions.map(a => user.signTypedData(domain, types, a))
);

await account.connect(sponsor).executeBatch(actions, signatures);
```

### Policy Configuration (Simple7702Account Only)

```solidity
// Only allow specific sponsors
registry.setWhitelistFlags(true, false);
registry.setSponsorWhitelist(trustedRelayer, true);

// Or restrict callable targets
registry.setWhitelistFlags(false, true);
registry.setTargetWhitelist(allowedContract, true);

// Or both
registry.setWhitelistFlags(true, true);
```

## Installation

```bash
# Requirements: Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Build
forge build

# Test
forge test

# Deploy Simple7702Account
./script/deploy.sh deploy amoy

# Deploy Universal7702Account
./script/deploy_universal.sh deploy amoy
```

## Project Structure

```
simple7702/
├── src/
│   ├── Simple7702Account.sol      # Policy-controlled account (~230 lines)
│   ├── Simple7702PolicyRegistry.sol # Policy registry (~80 lines)
│   └── Universal7702Account.sol   # Universal account (~190 lines)
├── script/
│   ├── Deploy.s.sol               # Simple7702 deployment script
│   ├── DeployUniversal.s.sol      # Universal7702 deployment script
│   ├── Create2Deployer.sol        # Deterministic deployment
│   ├── deploy.sh                  # Simple7702 deploy command
│   ├── deploy_universal.sh        # Universal7702 deploy command
│   └── config/
│       └── DeployConfig.sol       # Chain configurations
├── test/
│   └── Simple7702Account.t.sol    # Test suite
└── foundry.toml
```

## License

MIT
