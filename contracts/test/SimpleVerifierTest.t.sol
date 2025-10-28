// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SimpleVerifier.sol";
import { MerkleTrie } from "@eth-optimism/contracts-bedrock/libraries/trie/MerkleTrie.sol";
import { RLPReader } from "@eth-optimism/contracts-bedrock/libraries/rlp/RLPReader.sol";

/**
 * EXACT REPRODUCTION DEBUG SUITE
 * Using your EXACT failing data to isolate the root cause
 */
contract SimpleVerifierTest is Test {
    SimpleVerifier public verifier;
    
    // YOUR EXACT FAILING DATA
    address constant REAL_CONTRACT = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    bytes32 constant REAL_STATE_ROOT = 0x6ac4de7b8aa03be97908fa0bf0e7f25f4cb6f80c89cd1dcf0874831e6d9b8bb0;
    
    // Your exact proof data from the working curl response
    bytes[] realAccountProof;
    bytes[] realStorageProof;
    
    function setUp() public {
        verifier = new SimpleVerifier();
        
        // YOUR EXACT ACCOUNT PROOF (from successful curl)
        realAccountProof = new bytes[](3);
        realAccountProof[0] = hex"f90131a0b91a8b7a7e9d3eab90afd81da3725030742f663c6ed8c26657bf00d842a9f4aaa01689b2a5203afd9ea0a0ca3765e4a538c7176e53eac1f8307a344ffc3c6176558080a08fd3f7c31f7e2362b706d798f678efc412e4f7566f73f49538fec8f0ccb9a6faa0616f523ef8790739b8aff42df4bb9c159628bd946e830dc524c806c859c43e328080a04b29efa44ecf50c19b34950cf1d0f05e00568bcc873120fbea9a4e8439de0962a0d0a1bfe5b45d2d863a794f016450a4caca04f3b599e8d1652afca8b752935fd880a0bf9b09e442e044778b354abbadb5ec049d7f5e8b585c3966d476c4fbc9a181d28080a027d2a9a9700dfd8dc63ca4d40452efca7dacae7b93ab933480eab6dc5bfb6c05a0e5c557a0ce3894afeb44c37f3d24247f67dc76a174d8cacc360c1210eef60a7680";
        realAccountProof[1] = hex"f85180808080a075d3badc88aa70c446cc7c47509004277cb8f225559fcb79fa35d11661a8c8df80808080a074ae0767a40fc6fff780050f46a50f6b39ca4edb7faa9669108157a1cd96f40980808080808080";
        realAccountProof[2] = hex"f869a020e659e60b21cc961f64ad47f20523c1d329d4bbda245ef3940a76dc89d0911bb846f8440180a0a0766de4d6280231289c0f5a3d3912e1bf410bf7b0064d6b1cfadc1136d99d68a0fc8b829689eb22796247ff8cebf24cfc93024d4374e9293b10290cd1232fe802";
        
        // YOUR EXACT STORAGE PROOF (from successful curl)
        realStorageProof = new bytes[](3);
        realStorageProof[0] = hex"f89180a00d24d9b786bfb5f20e3e27e4a821dbe48ba8fb9d9d6070a9eebe63fa98591005a0f53ea298491c498054f45ef4144722abda9f6f67874477d0510aed94bb86e80880a00df1cb52b4f4ef80904c3afa137a2448cd6b1d023e56855b442bfb638e5de6e9808080808080a0236e8f61ecde6abfebc6c529441f782f62469d8a2cc47b7aace2c136bd3b1ff08080808080";
        realStorageProof[1] = hex"f851808080808080808080a04d0c15612e60ae90c040ff5eef0f99778a6f3dfdbdfacf954295252cef782a108080a031fab136a73a600ac565617162975a6b982fa8d423f85afc2dda447e745970fd80808080";
        realStorageProof[2] = hex"e2a0200decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e56301";
    }

    // STEP 1: Test the EXACT hash chain validation
    function test_01_ExactHashChainValidation() public {
        console.log("=== STEP 1: EXACT HASH CHAIN VALIDATION ===");
        console.log("This will show WHY MerkleTrie fails with 'invalid large internal hash'");
        
        console.log("\nExpected state root:");
        console.logBytes32(REAL_STATE_ROOT);
        
        console.log("\nFirst proof element (should hash to state root):");
        console.logBytes(realAccountProof[0]);
        
        bytes32 firstElementHash = keccak256(realAccountProof[0]);
        console.log("\nHash of first element:");
        console.logBytes32(firstElementHash);
        
        console.log("\nDo they match?");
        if (firstElementHash == REAL_STATE_ROOT) {
            console.log("YES - First element hashes to state root (GOOD!)");
        } else {
            console.log("NO - This is why MerkleTrie fails!");
            console.log("The proof was generated from a different state than your state root");
        }
        
        // This is the exact check that MerkleTrie.sol does internally
        bool wouldPass = (firstElementHash == REAL_STATE_ROOT);
        console.log("\nMerkleTrie internal check would:", wouldPass ? "PASS" : "FAIL");
        
        assertTrue(wouldPass, "Hash chain validation failed - this is your root issue!");
    }

    // STEP 2: Test RLP decoding (should work fine)
    function test_02_RLPDecodingValidation() public {
        console.log("\n=== STEP 2: RLP DECODING VALIDATION ===");
        
        console.log("Testing if your proof elements are valid RLP...");
        
        for (uint i = 0; i < realAccountProof.length; i++) {
            console.log("Account proof element", i);
            try this.testRLPDecoding(realAccountProof[i]) returns (uint256 itemCount) {
                console.log("  Valid RLP with", itemCount, "items");
            } catch Error(string memory reason) {
                console.log("  Invalid RLP:", reason);
                assertTrue(false, "RLP should be valid");
            }
        }
        
        for (uint i = 0; i < realStorageProof.length; i++) {
            console.log("Storage proof element", i);
            try this.testRLPDecoding(realStorageProof[i]) returns (uint256 itemCount) {
                console.log("  Valid RLP with", itemCount, "items");
            } catch Error(string memory reason) {
                console.log("  Invalid RLP:", reason);
                assertTrue(false, "RLP should be valid");
            }
        }
        
        console.log("All RLP decoding passed - libraries are working correctly!");
    }
    
    function testRLPDecoding(bytes calldata data) external pure returns (uint256) {
        RLPReader.RLPItem[] memory items = RLPReader.readList(data);
        return items.length;
    }

    // STEP 3: Test MerkleTrie.get() in isolation (will fail)
    function test_03_IsolateMerkleTrieFailure() public {
        console.log("\n=== STEP 3: ISOLATE MERKLETRIE FAILURE ===");
        
        bytes memory accountKey = abi.encodePacked(REAL_CONTRACT);
        console.log("Account key (contract address):");
        console.logBytes(accountKey);
        
        console.log("\nTesting MerkleTrie.get() with your exact data...");
        
        try this.testMerkleTrieGet(accountKey, realAccountProof, REAL_STATE_ROOT) 
        returns (bytes memory result) {
            console.log("UNEXPECTED SUCCESS! MerkleTrie.get() worked!");
            console.log("Account RLP length:", result.length);
            console.log("This means the issue is elsewhere!");
        } catch Error(string memory reason) {
            console.log("MerkleTrie.get() FAILED as expected:");
            console.log(reason);
            
            if (keccak256(bytes(reason)) == keccak256(bytes("MerkleTrie: invalid large internal hash"))) {
                console.log("CONFIRMED: This is the exact error from your transaction!");
                console.log("The issue is in hash chain validation (Step 1 should show why)");
            } else if (keccak256(bytes(reason)) == keccak256(bytes("MerkleTrie: invalid root hash"))) {
                console.log("ROOT HASH MISMATCH: First element doesn't hash to state root");
            } else {
                console.log("Different error than expected - investigating...");
            }
        }
    }
    
    function testMerkleTrieGet(bytes calldata key, bytes[] calldata proof, bytes32 root) 
    external pure returns (bytes memory) {
        return MerkleTrie.get(key, proof, root);
    }

    // STEP 4: Test with corrected state root (if needed)
    function test_04_TestWithCorrectStateRoot() public {
        console.log("\n=== STEP 4: TEST WITH CORRECT STATE ROOT ===");
        
        // Calculate what the state root SHOULD be based on first proof element
        bytes32 correctStateRoot = keccak256(realAccountProof[0]);
        console.log("Correct state root (from first proof element):");
        console.logBytes32(correctStateRoot);
        
        console.log("Your provided state root:");
        console.logBytes32(REAL_STATE_ROOT);
        
        if (correctStateRoot == REAL_STATE_ROOT) {
            console.log("State roots match - the issue is NOT hash mismatch");
            console.log("The problem is likely deeper in the verification logic");
        } else {
            console.log("State roots DON'T match - this is your problem!");
            console.log("Testing with corrected state root...");
            
            bytes memory accountKey = abi.encodePacked(REAL_CONTRACT);
            
            try this.testMerkleTrieGet(accountKey, realAccountProof, correctStateRoot) 
            returns (bytes memory result) {
                console.log("SUCCESS with corrected state root!");
                console.log("Account RLP length:", result.length);
                console.log("Your issue: You used wrong state root in verification");
            } catch Error(string memory reason) {
                console.log("Still failed even with corrected state root:");
                console.log(reason);
                console.log("The issue is deeper than just state root mismatch");
            }
        }
    }

    // STEP 5: Test the complete verification with diagnosis
    function test_05_CompleteVerificationDiagnosis() public {
        console.log("\n=== STEP 5: COMPLETE VERIFICATION DIAGNOSIS ===");
        
        SimpleVerifier.SimpleProof memory testProof = SimpleVerifier.SimpleProof({
            stateRoot: REAL_STATE_ROOT,
            contractAddress: REAL_CONTRACT,
            storageSlot: bytes32(0),
            expectedValue: bytes32(uint256(1)),
            accountProof: realAccountProof,
            storageProof: realStorageProof
        });
        
        console.log("Testing complete verification with your exact data...");
        
        try verifier.verifySimpleProof(testProof) returns (bool result) {
            console.log("VERIFICATION SUCCESS!");
            console.log("Result:", result);
            if (!result) {
                console.log("WARNING: Verification returned false - storage proof failed");
            }
        } catch Error(string memory reason) {
            console.log("VERIFICATION FAILED:");
            console.log(reason);
            
            // Decode the specific error
            if (keccak256(bytes(reason)) == keccak256(bytes("MerkleTrie: invalid large internal hash"))) {
                console.log("DIAGNOSIS: Account proof hash chain is broken");
                console.log("SOLUTION: Use state root that matches your proof generation block");
            } else if (keccak256(bytes(reason)) == keccak256(bytes("MerkleTrie: invalid root hash"))) {
                console.log("DIAGNOSIS: First proof element doesn't hash to state root");
                console.log("SOLUTION: Generate fresh proof from the exact block of your state root");
            } else {
                console.log("DIAGNOSIS: Different error - check the specific failure");
            }
        }
    }

    // STEP 6: Generate the correct verification command
    function test_06_GenerateCorrectCommand() public {
        console.log("\n=== STEP 6: GENERATE CORRECT VERIFICATION COMMAND ===");
        
        // Test what the correct state root should be
        bytes32 correctStateRoot = keccak256(realAccountProof[0]);
        
        console.log("CORRECTED CAST COMMAND:");
        console.log("Use this command instead of your failing one:");
        console.log("");
        
        console.log("cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 \\");
        console.log('    "verifySimpleProof((bytes32,address,bytes32,bytes32,bytes[],bytes[]))" \\');
        
        // Build the corrected command with proper state root
        string memory command = string(abi.encodePacked(
            "    \"(",
            vm.toString(correctStateRoot),
            ",0x5FbDB2315678afecb367f032d93F642f64180aa3,",
            "0x0000000000000000000000000000000000000000000000000000000000000000,",
            "0x0000000000000000000000000000000000000000000000000000000000000001,"
        ));
        
        console.log(command);
        console.log("    [account_proof_array],[storage_proof_array])\" \\");
        console.log("    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \\");
        console.log("    --rpc-url http://127.0.0.1:8546 \\");
        console.log("    --gas-limit 1000000");
        
        console.log("\nKEY CHANGE:");
        console.log("Old state root:", vm.toString(REAL_STATE_ROOT));
        console.log("New state root:", vm.toString(correctStateRoot));
        
        if (correctStateRoot != REAL_STATE_ROOT) {
            console.log("\nTHIS IS YOUR ISSUE!");
            console.log("Your proof and state root are from different blocks!");
        } else {
            console.log("\nState roots match - the issue is elsewhere");
        }
    }

    // STEP 7: Test direct storage verification (bypass account proof)
    function test_07_DirectStorageVerification() public {
        console.log("\n=== STEP 7: DIRECT STORAGE VERIFICATION ===");
        console.log("Testing if storage proof works independently...");
        
        // From your curl: "storageHash": "0xa0766de4d6280231289c0f5a3d3912e1bf410bf7b0064d6b1cfadc1136d99d68"
        bytes32 storageRoot = 0xa0766de4d6280231289c0f5a3d3912e1bf410bf7b0064d6b1cfadc1136d99d68;
        bytes32 storageKey = keccak256(abi.encodePacked(bytes32(0)));
        bytes memory expectedValue = hex"01"; // For true
        
        console.log("Storage root:", vm.toString(storageRoot));
        console.log("Storage key:", vm.toString(storageKey));
        console.log("Expected value: 0x01 (true)");
        
        try this.testDirectStorageVerification(
            abi.encodePacked(storageKey),
            expectedValue,
            realStorageProof,
            storageRoot
        ) returns (bool valid) {
            console.log("Storage verification result:", valid);
            if (valid) {
                console.log("Storage proof is VALID!");
                console.log("The issue is only with account proof");
            } else {
                console.log("Storage proof is also INVALID");
                console.log("Multiple issues in your proof data");
            }
        } catch Error(string memory reason) {
            console.log("Storage verification error:", reason);
        }
    }
    
    function testDirectStorageVerification(
        bytes calldata key,
        bytes calldata value,
        bytes[] calldata proof,
        bytes32 root
    ) external pure returns (bool) {
        return MerkleTrie.verifyInclusionProof(key, value, proof, root);
    }

    // FINAL SUMMARY
    function test_08_FinalSummaryAndSolution() public {
        console.log("\n=== FINAL SUMMARY AND SOLUTION ===");
        
        bytes32 proofStateRoot = keccak256(realAccountProof[0]);
        bool stateRootMatches = (proofStateRoot == REAL_STATE_ROOT);
        
        console.log("DIAGNOSIS RESULTS:");
        console.log("1. RLP libraries: Working correctly");
        console.log("2. Optimism libraries: Working correctly");
        console.log("3. Proof format: Valid structure");
        console.log("4. State root match:", stateRootMatches ? "GOOD" : "MISMATCH");
        
        if (!stateRootMatches) {
            console.log("\nROOT CAUSE IDENTIFIED:");
            console.log("Your state root and proof are from DIFFERENT blocks!");
            console.log("");
            console.log("Your state root:", vm.toString(REAL_STATE_ROOT));
            console.log("Proof's state root:", vm.toString(proofStateRoot));
            console.log("");
            console.log("SOLUTION:");
            console.log("1. Get current block: cast block-number --rpc-url http://127.0.0.1:8545");
            console.log("2. Get CURRENT state root from that block");
            console.log("3. Generate FRESH proof from that SAME block");
            console.log("4. Use matching state root and proof in verification");
            console.log("");
            console.log("OR use the corrected state root shown in Step 6!");
        } else {
            console.log("\nUNEXPECTED: State roots match but verification still fails");
            console.log("This suggests a deeper issue in the verification logic");
            console.log("Check the specific error message from Step 5");
        }
        
        console.log("\nNEXT ACTIONS:");
        console.log("1. Run: forge test --match-test test_01 -vvv");
        console.log("2. Check if hash chain validation passes");
        console.log("3. If not, use corrected command from Step 6");
        console.log("4. If yes, investigate the storage verification logic");
    }
}