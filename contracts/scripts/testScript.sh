#!/bin/bash

# Automated helper to build a fully-populated cast command for verifySimpleProof.
# 1. Fetches eth_getProof for SimpleStorage slot 0 at the latest block.
# 2. Reads the block state root via cast.
# 3. Interpolates both into the cast send invocation and executes it.

set -euo pipefail

RPC_URL="http://127.0.0.1:8545"
SIMPLE_STORAGE="0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
VERIFIER="0x5FbDB2315678afecb367f032d93F642f64180aa3"
DEV_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
TARGET_SLOT="0x0000000000000000000000000000000000000000000000000000000000000000"

# Determine latest block and format as hex.
LATEST_BLOCK_DEC=$(cast block-number --rpc-url "$RPC_URL")

if [[ -z "$LATEST_BLOCK_DEC" ]]; then
    echo "Failed to read latest block number." >&2
    exit 1
fi

PROOF_BLOCK=$(printf '0x%x' "$LATEST_BLOCK_DEC")

echo "Using block $LATEST_BLOCK_DEC ($PROOF_BLOCK) for proof." >&2

# Step 1: Retrieve the storage proof JSON payload.
REQUEST_PAYLOAD=$(SIMPLE_STORAGE="$SIMPLE_STORAGE" TARGET_SLOT="$TARGET_SLOT" PROOF_BLOCK="$PROOF_BLOCK" python3 - <<'PY'
import json
import os

payload = {
    "jsonrpc": "2.0",
    "method": "eth_getProof",
    "params": [
        os.environ["SIMPLE_STORAGE"],
        [os.environ["TARGET_SLOT"]],
        os.environ["PROOF_BLOCK"],
    ],
    "id": 1,
}

print(json.dumps(payload))
PY
)

PROOF_JSON=$(curl -s -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    --data "$REQUEST_PAYLOAD")

if [[ -z "$PROOF_JSON" ]]; then
    echo "Failed to retrieve proof JSON." >&2
    exit 1
fi

# echo "Proof JSON: $PROOF_JSON" >&2

# Step 2: Parse proof components via helper (outputs key=value lines).
PROOF_VARS=$(echo "$PROOF_JSON" | python3 parse_proof.py)

if [[ -z "$PROOF_VARS" ]]; then
    echo "Proof parsing returned nothing." >&2
    exit 1
fi

ERROR_MSG=""
ACCOUNT_PROOF_STR=""
STORAGE_PROOF_STR=""
STORAGE_VALUE_RAW=""

while IFS='=' read -r key value; do
    [[ -z "$key" ]] && continue
    case "$key" in
        ERROR)
            ERROR_MSG="$value"
            ;;
        ACCOUNT_PROOF_STR)
            ACCOUNT_PROOF_STR="$value"
            ;;
        STORAGE_PROOF_STR)
            STORAGE_PROOF_STR="$value"
            ;;
        STORAGE_VALUE)
            STORAGE_VALUE_RAW="$value"
            ;;
    esac
done <<< "$PROOF_VARS"

if [[ -n "$ERROR_MSG" ]]; then
    echo "Proof parsing error: $ERROR_MSG" >&2
    exit 1
fi

if [[ -z "$ACCOUNT_PROOF_STR" || -z "$STORAGE_PROOF_STR" ]]; then
    echo "Proof parsing did not produce proof arrays." >&2
    exit 1
fi

if [[ -z "$STORAGE_VALUE_RAW" ]]; then
    echo "Proof parsing did not provide storage value." >&2
    exit 1
fi

# Step 3: Obtain the state root for the chosen block.
STATE_ROOT=$(cast block "$PROOF_BLOCK" --field stateRoot --rpc-url "$RPC_URL")

if [[ -z "$STATE_ROOT" ]]; then
    echo "Failed to read state root." >&2
    exit 1
fi

ACCOUNT_PROOF_ARRAY="[$ACCOUNT_PROOF_STR]"
STORAGE_PROOF_ARRAY="[$STORAGE_PROOF_STR]"

PADDED_STORAGE_VALUE=$(STORAGE_VALUE_RAW="$STORAGE_VALUE_RAW" python3 - <<'PY'
import os

value = os.environ["STORAGE_VALUE_RAW"].lower()
if value.startswith("0x"):
    value = value[2:]

if value == "":
    value = "0"

try:
    num = int(value, 16)
except ValueError as exc:
    raise SystemExit(f"Invalid storage value: {value}") from exc

print(f"0x{num:064x}")
PY
)

if [[ -z "$PADDED_STORAGE_VALUE" ]]; then
    echo "Failed to normalize storage value." >&2
    exit 1
fi

# Step 4: Execute the verification transaction.
cast send "$VERIFIER" \
    "verifySimpleProof((bytes32,address,bytes32,bytes32,bytes[],bytes[]))" \
    "($STATE_ROOT,$SIMPLE_STORAGE,$TARGET_SLOT,$PADDED_STORAGE_VALUE,$ACCOUNT_PROOF_ARRAY,$STORAGE_PROOF_ARRAY)" \
    --private-key "$DEV_PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    --gas-limit 1000000