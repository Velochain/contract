# Cycle2earn Smart Contract Documentation

## Overview

The `Cycle2earn` contract is a blockchain-based rewards system that incentivizes cycling activities tracked through Strava. It integrates with the VeChain x2earn rewards pool to distribute rewards to users based on their cycling activities.

**Contract Address:** `0x9B9CA9D0C41Add1d204f90BA0E9a6844f1843A84`

**Solidity Version:** `^0.8.20`

**License:** UNLICENSED

## Table of Contents

- [Architecture](#architecture)
- [Key Features](#key-features)
- [Contract Components](#contract-components)
  - [Structs](#structs)
  - [State Variables](#state-variables)
  - [Events](#events)
  - [Errors](#errors)
- [Functions](#functions)
  - [Constructor](#constructor)
  - [Public Functions](#public-functions)
  - [External Functions](#external-functions)
  - [Internal Functions](#internal-functions)
- [Security Considerations](#security-considerations)
- [Usage Examples](#usage-examples)
- [Integration Guide](#integration-guide)

## Architecture

The contract follows a three-tier architecture:

1. **User Layer**: Users connect their Strava accounts and claim rewards
2. **Verification Layer**: Backend verifier signs reward allocations using ECDSA signatures
3. **Distribution Layer**: Integration with IX2EarnRewardsPool for actual token distribution

```
┌─────────────────────────────────────────────────────────────┐
│                         User (Cyclist)                       │
│  - Connects Strava Account                                   │
│  - Completes Cycling Activities                              │
│  - Claims Rewards                                            │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                     Cycle2earn Contract                      │
│  - Maps Strava ID ↔ Wallet Address                          │
│  - Tracks Reward Allocations                                 │
│  - Verifies Signatures                                       │
└─────────────────┬───────────────────────────────────────────┘
                  │
        ┌─────────┴──────────┐
        ▼                    ▼
┌──────────────┐    ┌─────────────────────┐
│   Verifier   │    │ X2EarnRewardsPool   │
│   (Backend)  │    │   (VeChain DAO)     │
│ - Signs      │    │ - Distributes       │
│   Rewards    │    │   Tokens            │
└──────────────┘    └─────────────────────┘
```

## Key Features

- **Strava Integration**: Links user wallet addresses with Strava IDs
- **Reward Tracking**: Maintains total and claimed reward amounts per user
- **Signature Verification**: Uses ECDSA signatures to verify reward authenticity
- **Dual Reward Methods**: Supports both signature-based and direct (verifier-only) reward allocation
- **VeChain Integration**: Connects with VeBetterDAO's x2earn rewards pool

## Contract Components

### Structs

#### `Reward`
Tracks reward information for each user.

```solidity
struct Reward {
    uint256 totalAmount;   // Total amount of rewards allocated
    uint256 claimedAmount; // Amount of rewards already claimed
}
```

### State Variables

| Variable | Type | Visibility | Description |
|----------|------|------------|-------------|
| `verifier` | `address` | `public` | Address authorized to sign reward allocations |
| `x2EarnRewardsPool` | `IX2EarnRewardsPool` | `private` | Reference to the x2earn rewards pool contract |
| `VBD_APP_ID` | `bytes32` | `private` | Application ID registered with VeBetterDAO |
| `stravaIdToAddress` | `mapping(string => address)` | `public` | Maps Strava IDs to wallet addresses |
| `addressToStravaId` | `mapping(address => string)` | `public` | Maps wallet addresses to Strava IDs |
| `userClaimedCycles` | `mapping(address => string[])` | `private` | Stores claimed cycle IDs per user (currently unused) |
| `userRewards` | `mapping(address => Reward)` | `private` | Tracks rewards per user address |

### Events

#### `RewardAdded`
Emitted when rewards are allocated to a user.

```solidity
event RewardAdded(address indexed user, uint256 amount);
```

**Parameters:**
- `user`: Address of the user receiving rewards
- `amount`: Amount of rewards added

#### `RewardClaimed`
Emitted when a user claims their rewards.

```solidity
event RewardClaimed(address indexed user, uint256 amount);
```

**Parameters:**
- `user`: Address of the user claiming rewards
- `amount`: Amount of rewards claimed

#### `StravaConnected`
Emitted when a user connects their Strava account.

```solidity
event StravaConnected(address indexed user, string stravaId);
```

**Parameters:**
- `user`: Address of the user
- `stravaId`: Connected Strava ID

### Errors

#### `InvalidSignature`
Thrown when signature verification fails.

```solidity
error InvalidSignature(address recoveredAddress, ECDSA.RecoverError error);
```

**Parameters:**
- `recoveredAddress`: Address recovered from the signature
- `error`: Specific ECDSA recovery error

#### `StravaIdAlreadyConnected`
Thrown when attempting to connect a Strava ID that's already linked.

```solidity
error StravaIdAlreadyConnected();
```

#### `InvalidAmount`
Thrown when attempting to claim zero rewards.

```solidity
error InvalidAmount();
```

## Functions

### Constructor

```solidity
constructor(
    IX2EarnRewardsPool _x2EarnRewardsPool,
    bytes32 _VBD_APP_ID,
    address _verifier
)
```

Initializes the contract with required dependencies.

**Parameters:**
- `_x2EarnRewardsPool`: Address of the x2earn rewards pool contract
- `_VBD_APP_ID`: Application ID for VeBetterDAO integration
- `_verifier`: Address authorized to sign reward allocations

### Public Functions

#### `connectStrava`

```solidity
function connectStrava(string memory stravaId) public
```

Links a Strava ID to the caller's wallet address.

**Parameters:**
- `stravaId`: The Strava ID to connect

**Requirements:**
- Strava ID must not already be connected to another address

**Reverts:**
- `"StravaIdAlreadyConnected"` if the Strava ID is already linked

**Example:**
```solidity
cycle2earn.connectStrava("12345678");
```

---

#### `getUserStravaId`

```solidity
function getUserStravaId(address user) public view returns (string memory)
```

Retrieves the Strava ID associated with a user address.

**Parameters:**
- `user`: Address of the user

**Returns:**
- Strava ID string (empty if not connected)

**Example:**
```solidity
string memory stravaId = cycle2earn.getUserStravaId(userAddress);
```

---

#### `getUserRewards`

```solidity
function getUserRewards(address user) public view returns (Reward memory)
```

Retrieves reward information for a user.

**Parameters:**
- `user`: Address of the user

**Returns:**
- `Reward` struct containing `totalAmount` and `claimedAmount`

**Example:**
```solidity
Reward memory rewards = cycle2earn.getUserRewards(userAddress);
uint256 available = rewards.totalAmount - rewards.claimedAmount;
```

---

#### `getRewardHash`

```solidity
function getRewardHash(
    address user,
    uint256 amount
) public pure returns (bytes memory message)
```

Generates the message hash used for signature verification.

**Parameters:**
- `user`: Address of the user
- `amount`: Reward amount

**Returns:**
- Concatenated bytes of the user address (20 bytes) and amount

**Example:**
```solidity
bytes memory message = cycle2earn.getRewardHash(userAddress, 1000);
```

---

#### `claimReward`

```solidity
function claimReward(address user) public
```

Claims all unclaimed rewards for a user and distributes them via the x2earn pool.

**Parameters:**
- `user`: Address of the user claiming rewards

**Requirements:**
- User must have unclaimed rewards (totalAmount > claimedAmount)

**Reverts:**
- `"InvalidAmount"` if there are no rewards to claim

**Effects:**
- Updates `claimedAmount` to match `totalAmount`
- Calls `x2EarnRewardsPool.distributeReward()` to transfer tokens

**Example:**
```solidity
cycle2earn.claimReward(msg.sender);
```

### External Functions

#### `addReward`

```solidity
function addReward(
    address user,
    uint256 amount,
    bytes memory signature
) external
```

Allocates rewards to a user with signature verification from the verifier.

**Parameters:**
- `user`: Address of the user receiving rewards
- `amount`: Amount of rewards to allocate
- `signature`: ECDSA signature from the verifier

**Process:**
1. Constructs message hash from user address and amount
2. Converts to Ethereum signed message hash
3. Recovers signer address from signature
4. Verifies signer matches the verifier address
5. Adds reward amount to user's total

**Reverts:**
- `InvalidSignature` if signature verification fails

**Example:**
```solidity
bytes memory signature = getSignatureFromBackend(user, amount);
cycle2earn.addReward(user, 1000, signature);
```

---

#### `addRewardAlt`

```solidity
function addRewardAlt(address user, uint256 amount) external
```

Alternative method for the verifier to directly allocate rewards without signatures.

**Parameters:**
- `user`: Address of the user receiving rewards
- `amount`: Amount of rewards to allocate

**Requirements:**
- Can only be called by the verifier address

**Reverts:**
- `"InvalidSender"` if caller is not the verifier

**Example:**
```solidity
// Only callable by verifier
cycle2earn.addRewardAlt(user, 1000);
```

### Internal Functions

#### `isValidSignature`

```solidity
function isValidSignature(
    bytes32 messageHash,
    bytes memory signature
) internal view returns (bool, address, ECDSA.RecoverError)
```

Validates an ECDSA signature against the verifier address.

**Parameters:**
- `messageHash`: Hash of the signed message
- `signature`: ECDSA signature bytes

**Returns:**
- `bool`: Whether the signature is valid
- `address`: Recovered signer address
- `ECDSA.RecoverError`: Error code from recovery process

**Process:**
1. Attempts to recover signer address from signature
2. Checks if recovery was successful
3. Compares recovered address with verifier address

## Security Considerations

### Access Control

- **Verifier Role**: The verifier address has privileged access to add rewards. This address should be:
  - Securely stored (e.g., hardware wallet, HSM)
  - Regularly rotated if compromised
  - Monitored for unauthorized transactions

### Signature Security

- Uses OpenZeppelin's ECDSA library for signature verification
- Implements EIP-191 signed message format (`\x19Ethereum Signed Message:\n32...`)
- Prevents signature replay by checking against the verifier address

### Potential Vulnerabilities

1. **No Reward Limit**: There's no cap on reward amounts that can be allocated
2. **Centralization**: Single verifier address creates a central point of failure
3. **No Strava Disconnection**: Once connected, Strava IDs cannot be unlinked
4. **Unused Storage**: `userClaimedCycles` mapping is defined but never used

### Recommended Improvements

1. **Multi-signature Verifier**: Implement a multi-sig or governance mechanism for verifier role
2. **Rate Limiting**: Add maximum rewards per user per time period
3. **Strava Unlinking**: Allow users to disconnect and reconnect Strava accounts
4. **Pause Mechanism**: Implement emergency pause functionality
5. **Event Emissions**: Add missing event emissions in `addReward` and `addRewardAlt`

## Usage Examples

### Frontend Integration

```typescript
// 1. Connect Strava Account
async function connectStrava(stravaId: string) {
  const tx = await cycle2earnContract.connectStrava(stravaId);
  await tx.wait();
  console.log("Strava connected!");
}

// 2. Check User Rewards
async function checkRewards(userAddress: string) {
  const rewards = await cycle2earnContract.getUserRewards(userAddress);
  const available = rewards.totalAmount - rewards.claimedAmount;
  console.log(`Available rewards: ${ethers.formatEther(available)} tokens`);
}

// 3. Claim Rewards
async function claimRewards(userAddress: string) {
  const tx = await cycle2earnContract.claimReward(userAddress);
  await tx.wait();
  console.log("Rewards claimed!");
}
```

### Backend Integration (Verifier)

```typescript
// Generate signature for reward allocation
async function signReward(
  userAddress: string,
  amount: bigint,
  privateKey: string
) {
  const message = await cycle2earnContract.getRewardHash(userAddress, amount);
  const messageHash = ethers.hashMessage(message);
  const wallet = new ethers.Wallet(privateKey);
  const signature = await wallet.signMessage(ethers.getBytes(messageHash));
  return signature;
}

// Alternative: Direct reward allocation (as verifier)
async function allocateReward(userAddress: string, amount: bigint) {
  const tx = await cycle2earnContract.addRewardAlt(userAddress, amount);
  await tx.wait();
  console.log("Reward allocated!");
}
```

## Integration Guide

### Prerequisites

1. Deployed `IX2EarnRewardsPool` contract
2. VeBetterDAO application ID (`VBD_APP_ID`)
3. Verifier wallet address with private key

### Deployment Steps

1. **Deploy Contract**
   ```typescript
   const Cycle2earn = await ethers.getContractFactory("Cycle2earn");
   const cycle2earn = await Cycle2earn.deploy(
     x2EarnPoolAddress,
     vbdAppId,
     verifierAddress
   );
   await cycle2earn.waitForDeployment();
   ```

2. **Configure Backend**
   - Set up Strava OAuth integration
   - Implement webhook for activity tracking
   - Configure verifier private key securely
   - Set up reward calculation logic

3. **User Flow**
   ```
   User → Connect Wallet
       → Authenticate with Strava
       → Call connectStrava(stravaId)
       → Complete cycling activities
       → Backend monitors Strava API
       → Backend calls addReward() or addRewardAlt()
       → User calls claimReward()
       → Tokens distributed from x2EarnRewardsPool
   ```

### Environment Variables

```env
CYCLE2EARN_CONTRACT_ADDRESS=0x9B9CA9D0C41Add1d204f90BA0E9a6844f1843A84
X2EARN_POOL_ADDRESS=0x...
VBD_APP_ID=0x...
VERIFIER_PRIVATE_KEY=0x...
STRAVA_CLIENT_ID=...
STRAVA_CLIENT_SECRET=...
```

### API Integration Example

```typescript
// Strava webhook handler
app.post('/strava/webhook', async (req, res) => {
  const activity = req.body;
  
  // Get user's wallet address from Strava ID
  const walletAddress = await getWalletFromStravaId(activity.athlete_id);
  
  // Calculate reward based on activity
  const reward = calculateReward(activity);
  
  // Allocate reward (as verifier)
  await cycle2earnContract.addRewardAlt(walletAddress, reward);
  
  res.status(200).send('OK');
});
```

## Dependencies

- **OpenZeppelin Contracts v5.x**
  - `ECDSA`: Elliptic curve signature verification
  - `MessageHashUtils`: Message hashing utilities
- **Custom Interface**
  - `IX2EarnRewardsPool`: VeBetterDAO rewards pool interface

## License

This contract is UNLICENSED. Ensure proper licensing before production use.

---

**Last Updated:** October 8, 2025

**Contract Version:** 1.0.0

**Maintainer:** VeChain Hackathon Team

