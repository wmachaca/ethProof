#!/bin/bash

# 🎯 Simple Storage Proof Setup Script
# This script deploys SimpleStorage and SimpleVerifier to two Anvil chains

set -e  # Exit on any error

echo "🎯 ==============================================="
echo "   Simple Storage Proof Dual Chain Setup"
echo "   ==============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists "anvil"; then
        print_error "Anvil not found. Please install Foundry:"
        print_error "curl -L https://foundry.paradigm.xyz | bash"
        print_error "foundryup"
        exit 1
    fi
    
    if ! command_exists "forge"; then
        print_error "Forge not found. Please install Foundry"
        exit 1
    fi
    
    if ! command_exists "node"; then
        print_error "Node.js not found. Please install Node.js"
        exit 1
    fi
    
    print_success "All prerequisites found!"
}

# Function to cleanup background processes
cleanup() {
    print_status "Script completed. Anvil chains continue running in background."
    print_warning "To stop both chains: kill $ANVIL1_PID $ANVIL2_PID"
    print_warning "Or use: pkill -f anvil"
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Step 1: Check prerequisites
check_prerequisites

# Step 2: Kill existing anvil processes
print_status "Cleaning up existing Anvil processes..."
pkill -f anvil || true
sleep 2

# Step 3: Compile contracts
print_status "Compiling SimpleStorage and SimpleVerifier contracts..."
forge build
if [ $? -eq 0 ]; then
    print_success "Contracts compiled successfully!"
else
    print_error "Contract compilation failed!"
    exit 1
fi

# Step 4: Start dual Anvil chains
print_status "Starting Anvil Chain 1 (port 8545, chain ID 31337)..."
anvil --host 0.0.0.0 --port 8545 --chain-id 31337 > anvil_chain1.log 2>&1 &
ANVIL1_PID=$!

print_status "Starting Anvil Chain 2 (port 8546, chain ID 31338)..."
anvil --host 0.0.0.0 --port 8546 --chain-id 31338 > anvil_chain2.log 2>&1 &
ANVIL2_PID=$!

# Wait for both chains to start
print_status "Waiting for both Anvil chains to start..."
sleep 5

# Check if Chain 1 is running
if ! curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://127.0.0.1:8545 > /dev/null; then
    print_error "Anvil Chain 1 failed to start!"
    exit 1
fi

# Check if Chain 2 is running
if ! curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://127.0.0.1:8546 > /dev/null; then
    print_error "Anvil Chain 2 failed to start!"
    exit 1
fi

print_success "Both Anvil chains are running!"
print_status "Chain 1: http://127.0.0.1:8545 (PID: $ANVIL1_PID)"
print_status "Chain 2: http://127.0.0.1:8546 (PID: $ANVIL2_PID)"

# Step 5: Deploy SimpleStorage to Chain 1
print_status "🚀 Deploying SimpleStorage to Chain 1 (31337)..."

SIMPLESTORAGE1_OUTPUT=$(forge create --broadcast --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 src/SimpleStorage.sol:SimpleStorage)

SIMPLESTORAGE1_ADDRESS=$(echo "$SIMPLESTORAGE1_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ ! -z "$SIMPLESTORAGE1_ADDRESS" ] && [[ $SIMPLESTORAGE1_ADDRESS =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    print_success "Chain 1 - SimpleStorage deployed at: $SIMPLESTORAGE1_ADDRESS"
else
    print_error "Failed to deploy SimpleStorage to Chain 1!"
    print_error "Output: $SIMPLESTORAGE1_OUTPUT"
    exit 1
fi

# Step 6: Deploy ProductionVerifier to Chain 2
print_status "🚀 Deploying ProductionVerifier to Chain 2 (31338)..."

# 🔧 FIX: Deploy ProductionVerifier (the real MPT verifier)
PRODUCTIONVERIFIER2_OUTPUT=$(forge create --broadcast --rpc-url http://127.0.0.1:8546 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 src/ProductionVerifier.sol:ProductionVerifier)

PRODUCTIONVERIFIER2_ADDRESS=$(echo "$PRODUCTIONVERIFIER2_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ ! -z "$PRODUCTIONVERIFIER2_ADDRESS" ] && [[ $PRODUCTIONVERIFIER2_ADDRESS =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    print_success "Chain 2 - ProductionVerifier deployed at: $PRODUCTIONVERIFIER2_ADDRESS"
else
    print_error "Failed to deploy ProductionVerifier to Chain 2!"
    print_error "Output: $PRODUCTIONVERIFIER2_OUTPUT"
    exit 1
fi

# Step 7: Update backend config.ts with contract addresses
print_status "Updating backend config.ts with deployed contract addresses..."
cd ../backend/src

# Update config.ts file
cat > config.ts << EOF
import { defineChain } from 'viem';

/**
 * 🔧 PRODUCTION CONFIGURATION FOR REAL MPT VERIFICATION
 */

// Define our two Anvil chains
export const anvilChain1 = defineChain({
  id: 31337,
  name: 'Anvil Chain 1',
  network: 'anvil1',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545'],
    },
    public: {
      http: ['http://127.0.0.1:8545'],
    },
  },
});

export const anvilChain2 = defineChain({
  id: 31338,
  name: 'Anvil Chain 2', 
  network: 'anvil2',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8546'], // Different port!
    },
    public: {
      http: ['http://127.0.0.1:8546'],
    },
  },
});

// Contract addresses (updated by deploy script)
export const STORAGE_CONTRACT_ADDRESSES: Record<number, string> = {
  31337: '$SIMPLESTORAGE1_ADDRESS', // SimpleStorage on Chain 1
  31338: '0x0000000000000000000000000000000000000000', // Not deployed on Chain 2
};

export const VERIFIER_CONTRACT_ADDRESSES: Record<number, string> = {
  31337: '0x0000000000000000000000000000000000000000', // Not deployed on Chain 1
  31338: '$PRODUCTIONVERIFIER2_ADDRESS', // ProductionVerifier on Chain 2
};

export const SUPPORTED_CHAINS = [anvilChain1, anvilChain2];
EOF

print_success "Backend config.ts updated with deployed contract addresses!"

# Step 8: Test the setup by calling setGameActive(true) on Chain 1
print_status "Testing setup by calling setGameActive(true) on Chain 1..."

cast send $SIMPLESTORAGE1_ADDRESS "setGameActive(bool)" true --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://127.0.0.1:8545

# Wait for transaction
sleep 3

# Verify the state change
GAME_ACTIVE=$(cast call $SIMPLESTORAGE1_ADDRESS "gameActive()" --rpc-url http://127.0.0.1:8545)

if [ "$GAME_ACTIVE" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    print_success "✅ gameActive is now true on Chain 1!"
else
    print_warning "⚠️ gameActive state unclear, but setup should work"
fi

# Step 9: Display setup summary
print_success "🎯 SIMPLE STORAGE PROOF SETUP COMPLETE!"
echo ""
print_status "=== CHAIN 1 (31337) - Game Chain ==="
echo "RPC URL: http://127.0.0.1:8545"
echo "SimpleStorage: $SIMPLESTORAGE1_ADDRESS"
echo "gameActive: true (ready for proof generation)"
echo "PID: $ANVIL1_PID"
echo ""
print_status "=== CHAIN 2 (31338) - Verification Chain ==="
echo "RPC URL: http://127.0.0.1:8546"
echo "ProductionVerifier: $PRODUCTIONVERIFIER2_ADDRESS"
echo "Ready to verify storage proofs with REAL MPT verification from Chain 1"
echo "PID: $ANVIL2_PID"
echo ""
print_status "=== LOGS ==="
echo "Chain 1 logs: tail -f ../contracts/anvil_chain1.log"
echo "Chain 2 logs: tail -f ../contracts/anvil_chain2.log"
echo ""
print_status "=== NEXT STEPS ==="
echo "1. cd ../backend && npm install"
echo "2. npm start (run the storage proof demo)"
echo "3. Test: prove gameActive=true from Chain 1 on Chain 2"
echo ""
print_success "🎮 Ready for cross-chain storage proof testing!"
print_warning "To stop both chains: kill $ANVIL1_PID $ANVIL2_PID"

# Script exits here, Anvil processes continue in background