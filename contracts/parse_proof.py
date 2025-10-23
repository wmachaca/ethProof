#!/usr/bin/env python3
import json
import sys

def parse_proof(json_data):
    try:
        data = json.loads(json_data)
        result = data['result']
        
        # Extract key components
        storage_proof = result['storageProof'][0]
        
        # Ensure proper hex formatting (add 0x prefix if missing)
        def ensure_hex_prefix(value):
            if isinstance(value, str) and not value.startswith('0x'):
                return '0x' + value
            return value
        
        storage_key = ensure_hex_prefix(storage_proof['key'])
        storage_value = ensure_hex_prefix(storage_proof['value'])
        
        print(f"STORAGE_KEY={storage_key}")
        print(f"STORAGE_VALUE={storage_value}")
        print(f"ACCOUNT_PROOF_COUNT={len(result['accountProof'])}")
        print(f"STORAGE_PROOF_COUNT={len(storage_proof['proof'])}")
        
        # Format arrays for bash - FIXED for cast command
        # Cast expects: [item1,item2,item3] format for bytes[] arrays
        account_proof_items = []
        for item in result['accountProof']:
            hex_item = ensure_hex_prefix(item)
            account_proof_items.append(hex_item)  # No quotes around individual items
        
        storage_proof_items = []
        for item in storage_proof['proof']:
            hex_item = ensure_hex_prefix(item)
            storage_proof_items.append(hex_item)  # No quotes around individual items
        
        # Join with commas for cast command
        account_proof = ','.join(account_proof_items)
        storage_proof_arr = ','.join(storage_proof_items)
        
        print(f"ACCOUNT_PROOF_STR={account_proof}")
        print(f"STORAGE_PROOF_STR={storage_proof_arr}")
        
    except Exception as e:
        print(f"ERROR=Failed to parse: {e}")

if __name__ == "__main__":
    json_data = sys.stdin.read()
    parse_proof(json_data)
