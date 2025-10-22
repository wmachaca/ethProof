# 🎯 Simple Storage Proof - Cross-Chain Messaging

**GOAL**: Prove that `gameActive = true` happened on Chain A, verify it on Chain B.

## 🎯 What This Demonstrates

- **Storage Proofs**: How to prove contract state exists on another blockchain
- **eth_getProof**: Using Ethereum's native RPC method for Merkle proofs
- **Cross-Chain Verification**: Verifying storage values between two chains

## 🏗️ Architecture

```
Chain 1 (Anvil :8545)          Chain 2 (Anvil :8546)
┌─────────────────────┐        ┌─────────────────────┐
│   SimpleStorage     │        │  SimpleVerifier     │
│                     │        │                     │
│ bool gameActive ────┼────────┼──> verifyProof()    │
│ (storage slot 0)    │ proof  │                     │
└─────────────────────┘        └─────────────────────┘
           │                              │
           └── eth_getProof ──────────────┘
```

## 🚀 Quick Start

1. **Start two Anvil chains:**
   ```bash
   # Terminal 1 - Chain 1
   anvil --port 8545 --chain-id 31337

   # Terminal 2 - Chain 2  
   anvil --port 8546 --chain-id 31338
   ```

2. **Install dependencies:**
   ```bash
   cd backend
   npm install
   ```

3. **Deploy contracts:**
   ```bash
   # Deploy to both chains and update config.ts with addresses
   ```

4. **Run demo:**
   ```bash
   npm start
   ```

## 🔧 How It Works

### Storage Key Calculation
```typescript
// For: bool public gameActive (slot 0)
const storageKey = pad(toHex(0), { size: 32 });
// Result: 0x0000000000000000000000000000000000000000000000000000000000000000
```

### eth_getProof Call
```typescript
const proof = await client.request({
  method: 'eth_getProof',
  params: [
    contractAddress,  // Contract to prove
    [storageKey],     // Storage slots to prove  
    blockNumber       // Block number (hex)
  ]
});
```

### Proof Structure
```typescript
{
  accountProof: string[],    // Proof account exists in state trie
  storageProof: [{
    key: string,             // Storage slot key
    value: string,           // Storage slot value
    proof: string[]          // Merkle proof for storage
  }]
}
```

## 📚 Key Concepts

- **State Trie**: Every block has a Merkle tree of all account states
- **Storage Trie**: Each contract account has a Merkle tree of storage
- **eth_getProof**: Native Ethereum method to get inclusion proofs
- **Cross-Chain**: Proofs can be verified on any EVM chain

## 🎮 Next Steps

Once this works, you can apply the same concepts to your Rock-Paper-Scissors game:
1. Store game moves in contract storage
2. Generate proofs for moves on one chain
3. Verify moves on another chain
4. Resolve cross-chain games!