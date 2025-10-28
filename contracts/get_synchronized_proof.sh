#!/bin/bash

echo "🔄 GETTING SYNCHRONIZED PROOF AND STATE ROOT"

# Get the current block
CURRENT_BLOCK=$(cast block-number --rpc-url http://127.0.0.1:8545)
echo "Current block: $CURRENT_BLOCK"

# Get state root from current block
CURRENT_STATE_ROOT=$(cast block $CURRENT_BLOCK --field stateRoot --rpc-url http://127.0.0.1:8545)
echo "Current state root: $CURRENT_STATE_ROOT"

# Convert to hex
CURRENT_BLOCK_HEX=$(printf "0x%x" $CURRENT_BLOCK)

# Get proof from SAME block
echo "Getting proof from block $CURRENT_BLOCK_HEX..."

SYNCHRONIZED_PROOF=$(curl -s -X POST -H "Content-Type: application/json" --data "{
  \"jsonrpc\":\"2.0\",
  \"method\":\"eth_getProof\",
  \"params\":[
    \"0x5FbDB2315678afecb367f032d93F642f64180aa3\",
    [\"0x0000000000000000000000000000000000000000000000000000000000000000\"],
    \"$CURRENT_BLOCK_HEX\"
  ],
  \"id\":1
}" http://127.0.0.1:8545)

echo "✅ Synchronized proof generated!"
echo "State root and proof are now from the SAME block: $CURRENT_BLOCK"
echo ""
echo "Use this data for verification:"
echo "$SYNCHRONIZED_PROOF"
