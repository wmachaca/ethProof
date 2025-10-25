#!/usr/bin/env python3
import json
import sys

def parse_proof(json_data):
    try:
        data = json.loads(json_data)
        
        # Check for JSON-RPC error
        if 'error' in data:
            print(f"ERROR=JSON-RPC error: {data['error']['message']}")
            return
            
        if 'result' not in data:
            print("ERROR=No result field in response")
            return
            
        result = data['result']
        
        # Validate result structure
        if not isinstance(result, dict):
            print("ERROR=Result is not an object")
            return
            
        if 'storageProof' not in result or not result['storageProof']:
            print("ERROR=No storageProof in result")
            return
            
        # Extract key components
        storage_proof = result['storageProof'][0]
        
        # Ensure proper hex formatting
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
        
        # 🔥 FIXED: Proper array formatting for cast command
        # Cast expects comma-separated hex values for bytes[] arrays
        
        if len(result['accountProof']) > 0:
            account_proof_items = []
            for item in result['accountProof']:
                hex_item = ensure_hex_prefix(item)
                account_proof_items.append(hex_item)
            account_proof = ','.join(account_proof_items)
        else:
            account_proof = ""
        
        if len(storage_proof['proof']) > 0:
            storage_proof_items = []
            for item in storage_proof['proof']:
                hex_item = ensure_hex_prefix(item)
                storage_proof_items.append(hex_item)
            storage_proof_arr = ','.join(storage_proof_items)
        else:
            storage_proof_arr = ""
        
        print(f"ACCOUNT_PROOF_STR={account_proof}")
        print(f"STORAGE_PROOF_STR={storage_proof_arr}")
        
        # 🔍 DEBUG: Print first few characters of proofs for verification
        if account_proof:
            first_account = result['accountProof'][0][:20] if result['accountProof'] else "none"
            print(f"# DEBUG: First account proof starts with: {first_account}...")
            
        if storage_proof_arr:
            first_storage = storage_proof['proof'][0][:20] if storage_proof['proof'] else "none"
            print(f"# DEBUG: First storage proof starts with: {first_storage}...")
        
    except json.JSONDecodeError as e:
        print(f"ERROR=Invalid JSON: {e}")
    except KeyError as e:
        print(f"ERROR=Missing required field: {e}")
    except Exception as e:
        print(f"ERROR=Unexpected error: {e}")

if __name__ == "__main__":
    json_data = sys.stdin.read()
    if not json_data.strip():
        print("ERROR=Empty input")
        sys.exit(1)
    parse_proof(json_data)
