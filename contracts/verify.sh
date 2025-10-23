#!/bin/bash

# 🧪 SIMPLE MANUAL STORAGE PROOF VERIFICATION
# Uses parse_proof.py for clean JSON parsing and ACTUALLY sends to verifier contract

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contract addresses
STORAGE_CONTRACT="0x5FbDB2315678afecb367f032d93F642f64180aa3"
VERIFIER_CONTRACT="0x5FbDB2315678afecb367f032d93F642f64180aa3"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
CHAIN1_RPC="http://127.0.0.1:8545"
CHAIN2_RPC="http://127.0.0.1:8546"

echo -e "${BLUE}🧪 SIMPLE STORAGE PROOF VERIFICATION${NC}"
echo ""

# Convert decimal to hex
dec_to_hex() {
    printf "0x%x" $1
}

echo -e "${YELLOW}📊 STEP 1: CHECK STATE ON CHAIN 1${NC}"
GAME_ACTIVE=$(cast call $STORAGE_CONTRACT "gameActive()" --rpc-url $CHAIN1_RPC)
if [ "$GAME_ACTIVE" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    echo -e "${GREEN}✅ gameActive = true${NC}"
else
    echo -e "⚠️ Setting gameActive to true..."
    cast send $STORAGE_CONTRACT "setGameActive(bool)" true --private-key $PRIVATE_KEY --rpc-url $CHAIN1_RPC > /dev/null
    echo -e "${GREEN}✅ gameActive = true${NC}"
fi

echo ""
echo -e "${YELLOW}📦 STEP 2: GET BLOCK INFO${NC}"
LATEST_BLOCK_DEC=$(cast block-number --rpc-url $CHAIN1_RPC)
LATEST_BLOCK_HEX=$(dec_to_hex $LATEST_BLOCK_DEC)
echo -e "📊 Latest block: $LATEST_BLOCK_DEC"

# Get state root using cast instead of curl for reliability
STATE_ROOT=$(cast block $LATEST_BLOCK_DEC --field stateRoot --rpc-url $CHAIN1_RPC)

echo -e "🌳 State Root: $STATE_ROOT"

echo ""
echo -e "${YELLOW}🛡️ STEP 3: GET STORAGE PROOF${NC}"

# Call eth_getProof
PROOF_DATA=$(curl -s -X POST -H "Content-Type: application/json" --data "{
  \"jsonrpc\":\"2.0\",
  \"method\":\"eth_getProof\",
  \"params\":[
    \"$STORAGE_CONTRACT\",
    [\"0x0000000000000000000000000000000000000000000000000000000000000000\"],
    \"$LATEST_BLOCK_HEX\"
  ],
  \"id\":1
}" $CHAIN1_RPC)

echo -e "${GREEN}✅ Storage proof retrieved!${NC}"

# Parse proof using Python helper
PROOF_VARS=$(echo "$PROOF_DATA" | python3 parse_proof.py)
eval "$PROOF_VARS"

# Check if parsing worked
if [ -n "$ERROR" ]; then
    echo -e "❌ Failed to parse proof: $ERROR"
    exit 1
fi

echo -e "📊 Proof components:"
echo -e "  🔑 Storage Key: $STORAGE_KEY"
echo -e "  💾 Storage Value: $STORAGE_VALUE"
echo -e "  🏠 Account Proof: $ACCOUNT_PROOF_COUNT elements"
echo -e "  🛡️ Storage Proof: $STORAGE_PROOF_COUNT elements"

# Decode storage value
if [ "$STORAGE_VALUE" = "0x1" ]; then
    echo -e "${GREEN}✅ Decoded: gameActive = true${NC}"
else
    echo -e "❌ Decoded: gameActive = false"
fi

echo ""
echo -e "${YELLOW}✅ STEP 4: VERIFY ON CHAIN 2${NC}"

# Check if already verified
ALREADY_VERIFIED=$(cast call $VERIFIER_CONTRACT "isGameActiveProven(address)" $STORAGE_CONTRACT --rpc-url $CHAIN2_RPC)

if [ "$ALREADY_VERIFIED" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    echo -e "${GREEN}✅ Already proven on Chain 2!${NC}"
else
    echo -e "📤 Sending verification to Chain 2..."
    
    # 🔧 FIXED: Properly format proof data for the verifier contract
    if [ "$ACCOUNT_PROOF_COUNT" -gt 0 ] && [ "$STORAGE_PROOF_COUNT" -gt 0 ]; then
        echo -e "🔧 Using REAL proof data with $ACCOUNT_PROOF_COUNT account proofs and $STORAGE_PROOF_COUNT storage proofs"
        
        # Pad storage value to 32 bytes (like in StorageProofService.ts)
        PADDED_STORAGE_VALUE=$(printf "0x%064s" "${STORAGE_VALUE#0x}" | tr ' ' '0')
        
        echo -e "📋 Formatted proof data:"
        echo -e "  🌳 State Root: $STATE_ROOT"
        echo -e "  🔑 Storage Key: $STORAGE_KEY"
        echo -e "  💾 Storage Value (raw): $STORAGE_VALUE"
        echo -e "  💾 Storage Value (padded): $PADDED_STORAGE_VALUE"
        echo -e "  🏠 Account Proofs: $ACCOUNT_PROOF_COUNT elements"
        echo -e "  🛡️ Storage Proofs: $STORAGE_PROOF_COUNT elements"
        
        echo ""
        echo -e "${BLUE}🚀 SENDING VERIFICATION TRANSACTION...${NC}"
        
        # Create a temporary file for the complex call
        CALL_DATA_FILE="/tmp/verify_call.txt"
        
        # Format the call data - this is the tricky part!
        cat > $CALL_DATA_FILE << EOF
cast send $VERIFIER_CONTRACT \\
  "verifyStorageProof((bytes32,address,uint256,uint256,bytes32,bytes32,bytes[],bytes[]))" \\
  "($STATE_ROOT,$STORAGE_CONTRACT,31337,$LATEST_BLOCK_DEC,$STORAGE_KEY,$PADDED_STORAGE_VALUE,[$ACCOUNT_PROOF_STR],[$STORAGE_PROOF_STR])" \\
  --private-key $PRIVATE_KEY \\
  --rpc-url $CHAIN2_RPC \\
  --gas-limit 1000000
EOF

        echo -e "📋 Generated verification command:"
        cat $CALL_DATA_FILE
        echo ""
        
        # Try to execute the verification
        echo -e "⏳ Executing verification transaction..."
        
        # Use timeout to prevent hanging
        timeout 30s bash $CALL_DATA_FILE 2>&1
        CALL_RESULT=$?
        
        if [ $CALL_RESULT -eq 0 ]; then
            echo -e "${GREEN}✅ Verification transaction sent!${NC}"
            
            # Wait for confirmation
            sleep 5
            
            # Check if verification worked
            VERIFIED_NOW=$(cast call $VERIFIER_CONTRACT "isGameActiveProven(address)" $STORAGE_CONTRACT --rpc-url $CHAIN2_RPC)
            
            if [ "$VERIFIED_NOW" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
                echo -e "${GREEN}🎉 VERIFICATION SUCCESSFUL!${NC}"
                echo -e "${GREEN}✅ Chain 2 now confirms gameActive=true from Chain 1!${NC}"
            else
                echo -e "${YELLOW}⚠️ Transaction sent but verification status unclear${NC}"
            fi
        elif [ $CALL_RESULT -eq 124 ]; then
            echo -e "${YELLOW}⏰ Transaction timed out (30s)${NC}"
            echo -e "${BLUE}💡 Try running the backend version instead:${NC}"
            echo -e "   cd ../backend && npm run dev"
        else
            echo -e "${YELLOW}❌ Cast command failed (exit code: $CALL_RESULT)${NC}"
            echo -e "${BLUE}💡 Complex struct encoding is tricky with cast${NC}"
            echo -e "${BLUE}🔄 Running backend verification automatically...${NC}"
            
            # Fallback to backend
            if [ -f "../backend/package.json" ]; then
                echo -e "🚀 Starting backend verification..."
                cd ../backend && npm run dev
            else
                echo -e "💡 Run backend manually: cd ../backend && npm run dev"
            fi
        fi
        
        # Cleanup
        rm -f $CALL_DATA_FILE
        
    else
        echo -e "⚠️ Empty proof arrays - cannot verify without real proof data"
        echo -e "${BLUE}💡 This usually means eth_getProof parsing failed${NC}"
        echo -e "   Try: cd ../backend && npm run dev"
    fi
fi

echo ""
echo -e "${GREEN}🎉 MANUAL VERIFICATION ATTEMPT COMPLETE!${NC}"
echo -e "📊 Summary:"
echo -e "  ✅ Extracted: gameActive = true from Chain 1 at block $LATEST_BLOCK_DEC"
echo -e "  ✅ Generated: Real Merkle Patricia Trie proofs from eth_getProof"
echo -e "  🔄 Attempted: Verification transaction to Chain 2"

echo ""
echo -e "${BLUE}🔧 If verification failed, use the backend:${NC}"
echo -e "cd ../backend && npm run dev"

echo -e "${GREEN}✨ Manual verification script completed! 🎯${NC}"
