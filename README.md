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

**Simple7702 strips away the complexity.** Just deploy two contracts and you're ready to sponsor transactions.

## The Problem with ERC-4337 Stack

Building on EIP-7702 + ERC-4337 means:

1. **Run a Paymaster** - Handle deposit management, gas estimation, sponsorship logic
2. **Run a Bundler** - Aggregate UserOps, simulate, submit to EntryPoint
3. **Deploy EntryPoint** - Another contract to manage, upgrade, secure
4. **Monitor Mempool** - Track UserOps, handle replacements, timeouts
5. **Complex Integration** - Client-side UserOp construction, signature schemes

This is overkill for many use cases. **Simple7702 provides a simpler alternative.**

## How Simple7702 Works

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

**Three simple steps:**

1. **User signs an action** - Off-chain, no gas required
2. **Sponsor submits the action** - Pays gas on behalf of user
3. **Contract verifies and executes** - Signature + policy check

That's it. No middleware, no additional services.

## Quick Start

### 1. Deploy

```bash
# Clone and build
git clone https://github.com/your-org/simple7702.git
cd simple7702
forge build

# Deploy (one command)
./script/deploy.sh
```

### 2. Set Up Policy (Optional)

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
- ✅ **Policy Controls** - Whitelist sponsors and/or targets

### Security Features

- ✅ **Signature Verification** - EIP-712 with low-s enforcement
- ✅ **Nonce Protection** - Bitmap-based replay prevention
- ✅ **Reentrancy Guard** - Protection against nested calls
- ✅ **Deadline Enforcement** - Actions expire after deadline

### Gas Optimized

- ✅ **Assembly Hashing** - EIP-712 digest computed in assembly
- ✅ **Cached Constants** - Pre-computed name/version hashes
- ✅ **Bitmap Nonces** - O(1) storage reads

## Comparison

### Simple7702 vs ERC-4337 Stack

| Aspect | ERC-4337 Stack | Simple7702 |
|--------|---------------|------------|
| **Setup Time** | Days to weeks | Minutes |
| **Infrastructure** | Paymaster + Bundler + EntryPoint | 2 contracts |
| **Maintenance** | High (multiple services) | Low (just contracts) |
| **Gas Overhead** | Higher (EntryPoint logic) | Lower (direct execution) |
| **Complexity** | High (UserOp, mempool) | Low (simple signature) |
| **Flexibility** | Constrained by EntryPoint | Full control |

### When to Use Simple7702

✅ **Perfect for:**
- DApps wanting to sponsor user transactions
- Simple meta-transaction needs
- Teams without infrastructure resources
- Quick EIP-7702 integration

❌ **Consider ERC-4337 if you need:**
- Complex account abstraction (social recovery, multi-sig)
- Shared Paymaster across many apps
- Advanced mempool features

## Architecture

### Contracts

| Contract | Lines | Description |
|----------|-------|-------------|
| [`Simple7702Account`](src/Simple7702Account.sol) | ~230 | Main delegate contract |
| [`Simple7702PolicyRegistry`](src/Simple7702PolicyRegistry.sol) | ~80 | Whitelist management |

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

### Policy Configuration

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

# Deploy
./script/deploy.sh
```

## Project Structure

```
simple7702/
├── src/
│   ├── Simple7702Account.sol      # Main account (~230 lines)
│   └── Simple7702PolicyRegistry.sol # Policy registry (~80 lines)
├── script/
│   ├── Deploy.s.sol               # Deployment script
│   ├── Create2Deployer.sol        # Deterministic deployment
│   └── deploy.sh                  # One-command deploy
├── test/
│   └── Simple7702Account.t.sol    # Test suite
└── foundry.toml
```

## License

MIT
