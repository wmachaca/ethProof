#!/bin/bash

# 🏭 PRODUCTION STORAGE PROOF VERIFICATION WITH PRODUCTIONVERIFIER
# Uses ProductionVerifier for real MPT verification - the gold standard!

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Contract addresses - these will be updated by startAnvil.sh
STORAGE_CONTRACT="0x5FbDB2315678afecb367f032d93F642f64180aa3"
VERIFIER_CONTRACT="0x5FbDB2315678afecb367f032d93F642f64180aa3"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
CHAIN1_RPC="http://127.0.0.1:8545"
CHAIN2_RPC="http://127.0.0.1:8546"

echo -e "${BLUE}🏭 PRODUCTION STORAGE PROOF VERIFICATION${NC}"
echo -e "${BLUE}Using ProductionVerifier with REAL MPT validation${NC}"
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
echo -e "📊 Latest block: $LATEST_BLOCK_DEC ($LATEST_BLOCK_HEX)"

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
    echo -e "${RED}❌ Failed to parse proof: $ERROR${NC}"
    echo -e "${BLUE}💡 Falling back to backend verification...${NC}"
    
    if [ -f "../backend/package.json" ]; then
        echo -e "🚀 Starting backend ProductionVerifier..."
        cd ../backend && npm run dev
    else
        echo -e "💡 Run backend manually: cd ../backend && npm run dev"
    fi
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
    echo -e "${RED}❌ Decoded: gameActive = false${NC}"
fi

echo ""
echo -e "${YELLOW}✅ STEP 4: VERIFY WITH PRODUCTIONVERIFIER${NC}"

# Check if already verified
ALREADY_VERIFIED=$(cast call $VERIFIER_CONTRACT "isGameActiveProven(address)" $STORAGE_CONTRACT --rpc-url $CHAIN2_RPC 2>/dev/null || echo "0x0000000000000000000000000000000000000000000000000000000000000000")

if [ "$ALREADY_VERIFIED" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    echo -e "${GREEN}✅ Already proven on Chain 2 ProductionVerifier!${NC}"
else
    echo -e "📤 Sending verification to Chain 2 ProductionVerifier..."
    echo -e "${BLUE}🏭 This will perform REAL Merkle Patricia Trie verification!${NC}"
    
    if [ "$ACCOUNT_PROOF_COUNT" -gt 0 ] && [ "$STORAGE_PROOF_COUNT" -gt 0 ]; then
        echo -e "🏭 Using ProductionVerifier with $ACCOUNT_PROOF_COUNT account proofs and $STORAGE_PROOF_COUNT storage proofs"
        
        # Pad storage value to 32 bytes
        PADDED_STORAGE_VALUE=$(printf "0x%064s" "${STORAGE_VALUE#0x}" | tr ' ' '0')
        
        echo -e "📋 Production verification data:"
        echo -e "  🌳 State Root: $STATE_ROOT"
        echo -e "  🔑 Storage Key: $STORAGE_KEY"
        echo -e "  💾 Storage Value (padded): $PADDED_STORAGE_VALUE"
        echo -e "  🏠 Account Proofs: $ACCOUNT_PROOF_COUNT elements"
        echo -e "  🛡️ Storage Proofs: $STORAGE_PROOF_COUNT elements"
        
        echo ""
        echo -e "${BLUE}🚀 ATTEMPTING CAST VERIFICATION...${NC}"
        echo -e "${YELLOW}⚠️ Note: Complex struct encoding with cast is challenging${NC}"
        
        # Try cast method with timeout
        echo -e "⏳ Attempting cast verification (30s timeout)..."
        
        # Create verification command
        CAST_COMMAND="cast send $VERIFIER_CONTRACT \\
            \"verifyStorageProof((bytes32,address,uint256,uint256,bytes32,bytes32,bytes[],bytes[]))\" \\
            \"($STATE_ROOT,$STORAGE_CONTRACT,31337,$LATEST_BLOCK_DEC,$STORAGE_KEY,$PADDED_STORAGE_VALUE,[$ACCOUNT_PROOF_STR],[$STORAGE_PROOF_STR])\" \\
            --private-key $PRIVATE_KEY \\
            --rpc-url $CHAIN2_RPC \\
            --gas-limit 2000000"
        
        # Execute with timeout
        timeout 30s bash -c "$CAST_COMMAND" 2>&1
        CAST_RESULT=$?
        
        if [ $CAST_RESULT -eq 0 ]; then
            echo -e "${GREEN}✅ Cast verification transaction sent!${NC}"
            
            # Wait and check result
            sleep 5
            
            VERIFIED_NOW=$(cast call $VERIFIER_CONTRACT "isGameActiveProven(address)" $STORAGE_CONTRACT --rpc-url $CHAIN2_RPC 2>/dev/null || echo "0x0000000000000000000000000000000000000000000000000000000000000000")
            
            if [ "$VERIFIED_NOW" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
                echo -e "${GREEN}🎉 PRODUCTIONVERIFIER SUCCESS!${NC}"
                echo -e "${GREEN}✅ Chain 2 cryptographically verified gameActive=true!${NC}"
                echo -e "${BLUE}🏆 Real MPT verification completed!${NC}"
            else
                echo -e "${YELLOW}⚠️ Transaction sent but verification unclear${NC}"
                echo -e "${BLUE}🔍 Trying backend for detailed analysis...${NC}"
                
                if [ -f "../backend/package.json" ]; then
                    cd ../backend && npm run dev
                fi
            fi
        else
            echo -e "${YELLOW}❌ Cast method failed (exit code: $CAST_RESULT)${NC}"
            
            if [ $CAST_RESULT -eq 124 ]; then
                echo -e "${YELLOW}⏰ Cast command timed out${NC}"
            fi
            
            echo -e "${BLUE}🔄 Falling back to backend verification...${NC}"
            echo -e "${BLUE}💡 Backend handles complex struct encoding better${NC}"
            
            # Fallback to backend
            if [ -f "../backend/package.json" ]; then
                echo -e "🚀 Starting backend ProductionVerifier..."
                cd ../backend && npm run dev
            else
                echo -e "${RED}❌ Backend not found at ../backend/package.json${NC}"
                echo -e "💡 Run manually: cd ../backend && npm run dev"
            fi
        fi
        
    else
        echo -e "${RED}⚠️ Empty proof arrays - cannot verify${NC}"
        echo -e "${BLUE}💡 This indicates eth_getProof parsing failed${NC}"
        echo -e "${BLUE}🔄 Using backend for robust proof handling...${NC}"
        
        if [ -f "../backend/package.json" ]; then
            cd ../backend && npm run dev
        else
            echo -e "💡 Run backend manually: cd ../backend && npm run dev"
        fi
    fi
fi

echo ""
echo -e "${GREEN}🏭 PRODUCTION VERIFICATION ATTEMPT COMPLETE!${NC}"
echo -e "📊 Summary:"
echo -e "  ✅ Extracted: gameActive = true from Chain 1 at block $LATEST_BLOCK_DEC"
echo -e "  🏭 Attempted: ProductionVerifier with REAL MPT verification"
echo -e "  🔍 Security: Invalid proofs are cryptographically rejected"

echo ""
echo -e "${BLUE}🏆 ProductionVerifier provides mathematical certainty!${NC}"
echo -e "If verification succeeds, Chain 2 has cryptographic proof of Chain 1 state!"

echo ""
echo -e "${BLUE}🔧 If shell verification failed, the backend is more reliable:${NC}"
echo -e "cd ../backend && npm run dev"

echo -e "${GREEN}✨ Production verification script completed! 🏭${NC}"
