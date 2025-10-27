# AI Agent Instructions - Cross-Chain Storage Proof System

## Architecture Overview

This is a **cross-chain storage proof verification system** that demonstrates cryptographic proof of storage state between two Ethereum chains using Merkle Patricia Trie (MPT) proofs and `eth_getProof` RPC calls.

### Core Components

- **Chain 1 (Port 8545)**: Source chain with `SimpleStorage.sol` contract storing `bool gameActive`
- **Chain 2 (Port 8546)**: Verification chain with `RealProductionVerifier.sol` for proof validation
- **Backend Service**: TypeScript service orchestrating proof generation and verification
- **Shell Scripts**: Automated deployment and testing workflows

### Data Flow
```
SimpleStorage (Chain 1) → eth_getProof → StorageProofService → RealProductionVerifier (Chain 2)
```

## Critical Development Workflows

### 1. Local Development Setup
```bash
# ALWAYS start with dual-chain deployment
cd contracts && ./startAnvil.sh

# Then run backend demo
cd ../backend && npm run dev
```

### 2. Manual Testing Workflow
```bash
# Deploy contracts and test verification
cd contracts && chmod +x verify.sh && ./verify.sh
```

### 3. Key Script Locations
- `contracts/startAnvil.sh`: Deploys contracts to both chains, updates addresses
- `contracts/verify.sh`: End-to-end manual verification demo
- `backend/src/StorageProofService.ts`: Main orchestration service

## Project-Specific Patterns

### Storage Proof Structure
All proofs follow this exact interface (see `StorageProofService.ts`):
```typescript
interface SimpleStorageProof {
  stateRoot: string;      // Block's state root from Chain 1
  sourceContract: string; // SimpleStorage address
  sourceChainId: number;  // 31337 (Chain 1)
  blockNumber: number;    // Proof block height
  storageKey: string;     // keccak256(slot) for bool gameActive (slot 0)
  storageValue: string;   // Expected value (0x01 for true)
  accountProof: string[]; // MPT proof from eth_getProof
  storageProof: string[]; // Storage MPT proof
}
```

### Contract Architecture Patterns
- **SimpleStorage**: Uses storage slot 0 for `gameActive` (critical for proof generation)
- **RealProductionVerifier**: Implements full MPT verification using `solidity-rlp` and custom `MPT.sol`
- **Storage Key Calculation**: `keccak256(pad(slot, 32))` for simple variables

### Chain Configuration
Two Anvil instances with specific chain IDs:
- Chain 1: ID 31337, RPC http://127.0.0.1:8545
- Chain 2: ID 31338, RPC http://127.0.0.1:8546

### Foundry Integration
- Uses OpenZeppelin contracts via git submodules in `lib/`
- Custom remappings in `foundry.toml` for `solidity-rlp` library
- Solidity 0.8.19 with heavy optimization (1M runs)

## External Dependencies

### Solidity Libraries
- `hamdiallam/solidity-rlp`: Industry standard RLP decoding
- `goldengate/MPT.sol`: Battle-tested Merkle Patricia Trie verification
- OpenZeppelin contracts for utilities

### TypeScript Stack
- **viem**: Modern Ethereum client (replaces ethers for this project)
- **Express**: REST API for proof orchestration
- **ts-node**: Direct TypeScript execution for scripts

## Cross-Component Communication

### Backend ↔ Contracts
- Backend generates proofs using `eth_getProof` from Chain 1
- Submits proofs to `RealProductionVerifier.verifyStorageProof()` on Chain 2
- Uses consistent address mapping in `config.ts`

### Shell Scripts ↔ Forge
- Scripts use `cast` commands exclusively (not `forge script`)
- Address updates happen via string replacement in deployment scripts
- Background process management for dual Anvil instances

## Development Guidelines

### When Adding New Storage Variables
1. Update storage slot calculations in `StorageProofService.calculateStorageKey()`
2. Ensure consistent slot numbering in both Solidity and TypeScript
3. Add corresponding proof methods following existing patterns

### When Modifying Verification Logic
1. Test with `verify.sh` script first for immediate feedback
2. Backend `npm run dev` provides full orchestration testing
3. Check both on-chain (`RealProductionVerifier`) and off-chain (`OffChainVerifier`) paths

### Port and Address Management
- Contracts automatically update addresses in config files after deployment
- Always use the generated addresses from `startAnvil.sh` output
- Backend reads from `config.ts` which gets updated by deployment scripts

This system demonstrates production-ready cross-chain verification patterns used by major protocols like LayerZero and Axelar.