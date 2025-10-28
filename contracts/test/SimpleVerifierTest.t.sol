// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SimpleVerifier.sol";
import { MerkleTrie } from "@eth-optimism/contracts-bedrock/libraries/trie/MerkleTrie.sol";
import { RLPReader } from "@eth-optimism/contracts-bedrock/libraries/rlp/RLPReader.sol";

/**
 * 🔥 REAL DATA DEBUG SUITE FOR SIMPLEVERIFIER
 * Using EXACT proof data from your anvil chains to isolate the failure
 */
contract SimpleVerifierTest is Test {
    SimpleVerifier public verifier;
    
    // 🎯 REAL DATA FROM YOUR ANVIL CHAINS
    address constant TEST_CONTRACT = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    bytes32 constant TEST_STATE_ROOT = 0xf8e851059d55137ab7c7ec064c931c4f6a214a65b9d36aa285942d424650789f;
    
    // Real account proof from your eth_getProof
    bytes[] realAccountProof;
    bytes[] realStorageProof;
    
    function setUp() public {
        verifier = new SimpleVerifier();
        
        // 🎯 REAL ACCOUNT PROOF DATA (exactly from your eth_getProof)
        realAccountProof = new bytes[](3);
        realAccountProof[0] = hex"f90131a0b91a8b7a7e9d3eab90afd81da3725030742f663c6ed8c26657bf00d842a9f4aaa01689b2a5203afd9ea0a0ca3765e4a538c7176e53eac1f8307a344ffc3c6176558080a0ad5db4aa5ac46aa22f103ad450aa04920cf35a758d5d4075cb010bc04dfab1cda0616f523ef8790739b8aff42df4bb9c159628bd946e830dc524c806c859c43e328080a04b29efa44ecf50c19b34950cf1d0f05e00568bcc873120fbea9a4e8439de0962a0d0a1bfe5b45d2d863a794f016450a4caca04f3b599e8d1652afca8b752935fd880a0bf9b09e442e044778b354abbadb5ec049d7f5e8b585c3966d476c4fbc9a181d28080a027d2a9a9700dfd8dc63ca4d40452efca7dacae7b93ab933480eab6dc5bfb6c05a0e5c557a0ce3894afeb44c37f3d24247f67dc76a174d8cacc360c1210eef60a7680";
        realAccountProof[1] = hex"f85180808080a0b615557349fece1590d22bcefdeb5ce719b7a3e320941f5420962793726a1b0b80808080a074ae0767a40fc6fff780050f46a50f6b39ca4edb7faa9669108157a1cd96f40980808080808080";
        realAccountProof[2] = hex"f869a020e659e60b21cc961f64ad47f20523c1d329d4bbda245ef3940a76dc89d0911bb846f8440180a0a0766de4d6280231289c0f5a3d3912e1bf410bf7b0064d6b1cfadc1136d99d68a030816f5b8543434c000ff69c9c416f19ca74260cf3226591f6afa3c5734c40f3";
        
        // 🎯 REAL STORAGE PROOF DATA (exactly from your eth_getProof)
        realStorageProof = new bytes[](3);
        realStorageProof[0] = hex"f89180a00d24d9b786bfb5f20e3e27e4a821dbe48ba8fb9d9d6070a9eebe63fa98591005a0f53ea298491c498054f45ef4144722abda9f6f67874477d0510aed94bb86e80880a00df1cb52b4f4ef80904c3afa137a2448cd6b1d023e56855b442bfb638e5de6e9808080808080a0236e8f61ecde6abfebc6c529441f782f62469d8a2cc47b7aace2c136bd3b1ff08080808080";
        realStorageProof[1] = hex"f851808080808080808080a04d0c15612e60ae90c040ff5eef0f99778a6f3dfdbdfacf954295252cef782a108080a031fab136a73a600ac565617162975a6b982fa8d423f85afc2dda447e745970fd80808080";
        realStorageProof[2] = hex"e2a0200decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e56301";
    }

    // 🎯 DEBUG 1: Verify RLP parsing works on real proof data
    function test_01_RLPParsingWorks() public {
        console.log("\n🔍 === STEP 1: RLP PARSING TEST ===");
        
        // Test RLP parsing of the first account proof element
        console.log("Testing RLP parsing of account proof[0]...");
        console.log("Length:", realAccountProof[0].length);
        
        // This should NOT revert if RLP is valid
        try this.parseAccountProof(realAccountProof[0]) returns (bool success) {
            assertTrue(success);
            console.log("✅ RLP parsing SUCCESS - Account proof is valid RLP");
        } catch Error(string memory reason) {
            console.log("❌ RLP parsing FAILED:");
            console.log(reason);
            assertTrue(false);
        }
    }
    
    // Helper function to test RLP parsing externally
    function parseAccountProof(bytes calldata rlpData) external pure returns (bool) {
        RLPReader.RLPItem[] memory parsed = RLPReader.readList(rlpData);
        return parsed.length > 0;
    }

    // 🎯 DEBUG 2: Test MerkleTrie.get() call in isolation
    function test_02_MerkleTrieGetIsolated() public {
        console.log("\n🔍 === STEP 2: MERKLETRIE GET ISOLATION ===");
        
        bytes memory contractAddressKey = abi.encodePacked(TEST_CONTRACT);
        console.log("Contract address as key:");
        console.logBytes(contractAddressKey);
        console.log("State root:");
        console.logBytes32(TEST_STATE_ROOT);
        
        // Test MerkleTrie.get() directly - this is where "invalid large internal hash" happens
        try this.testMerkleTrieGet(contractAddressKey, realAccountProof, TEST_STATE_ROOT) returns (bytes memory result) {
            console.log("✅ MerkleTrie.get() SUCCESS");
            console.log("Account RLP length:", result.length);
        } catch Error(string memory reason) {
            console.log("❌ MerkleTrie.get() FAILED:");
            console.log(reason);
            
            // This is likely where we'll see "MerkleTrie: invalid large internal hash"
            if (keccak256(bytes(reason)) == keccak256(bytes("MerkleTrie: invalid large internal hash"))) {
                console.log("🎯 FOUND THE EXACT ERROR!");
            }
        }
    }
    
    // Helper for isolated MerkleTrie.get() testing
    function testMerkleTrieGet(bytes calldata key, bytes[] calldata proof, bytes32 root) external pure returns (bytes memory) {
        return MerkleTrie.get(key, proof, root);
    }

    // 🎯 DEBUG 3: Verify storage key calculation matches expected
    function test_03_StorageKeyCalculation() public {
        console.log("\n🔍 === STEP 3: STORAGE KEY CALCULATION ===");
        
        bytes32 slot0 = bytes32(0);
        bytes32 calculatedKey = keccak256(abi.encodePacked(slot0));
        
        console.log("Slot 0:");
        console.logBytes32(slot0);
        console.log("Calculated storage key:");
        console.logBytes32(calculatedKey);
        
        // From your real storage proof, the key should be:
        // 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563
        bytes32 expectedFromProof = 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563;
        console.log("Expected from proof:");
        console.logBytes32(expectedFromProof);
        
        if (calculatedKey == expectedFromProof) {
            console.log("✅ Storage key calculation MATCHES");
        } else {
            console.log("❌ Storage key calculation MISMATCH - This could be the bug!");
        }
    }

    // 🎯 DEBUG 4: Test the EXACT real proof that fails
    function test_04_RealProofExactReproduction() public {
        console.log("\n🔍 === STEP 4: EXACT REAL PROOF TEST ===");
        
        SimpleVerifier.SimpleProof memory realProof = SimpleVerifier.SimpleProof({
            stateRoot: TEST_STATE_ROOT,
            contractAddress: TEST_CONTRACT,
            storageSlot: bytes32(0),
            expectedValue: bytes32(uint256(1)), // true = 1
            accountProof: realAccountProof,
            storageProof: realStorageProof
        });
        
        console.log("Using EXACT proof data from anvil:");
        console.log("State root:", vm.toString(realProof.stateRoot));
        console.log("Contract:", realProof.contractAddress);
        console.log("Storage slot:", vm.toString(realProof.storageSlot));
        console.log("Expected value:", vm.toString(realProof.expectedValue));
        console.log("Account proof elements:", realProof.accountProof.length);
        console.log("Storage proof elements:", realProof.storageProof.length);
        
        // This should reproduce the EXACT error you see in anvil
        try verifier.verifySimpleProof(realProof) returns (bool result) {
            if (result) {
                console.log("🎉 VERIFICATION SUCCESS! The proof is VALID!");
            } else {
                console.log("❌ Verification returned FALSE - proof invalid");
            }
        } catch Error(string memory reason) {
            console.log("💥 VERIFICATION REVERTED:");
            console.log(reason);
            
            // Check if it's the expected error
            if (keccak256(bytes(reason)) == keccak256(bytes("MerkleTrie: invalid large internal hash"))) {
                console.log("🎯 REPRODUCED THE EXACT ERROR!");
            }
        }
    }

    // 🎯 DEBUG 5: Test individual proof elements
    function test_05_ProofElementAnalysis() public {
        console.log("\n🔍 === STEP 5: PROOF ELEMENT ANALYSIS ===");
        
        console.log("Account Proof Analysis:");
        for (uint i = 0; i < realAccountProof.length; i++) {
            console.log("Element", i, "length:", realAccountProof[i].length);
            
            // Try to parse each element
            try this.parseProofElement(realAccountProof[i]) returns (bool success) {
                console.log("  ✅ Element", i, "RLP parsing OK");
            } catch {
                console.log("  ❌ Element", i, "RLP parsing FAILED");
            }
        }
        
        console.log("\nStorage Proof Analysis:");
        for (uint i = 0; i < realStorageProof.length; i++) {
            console.log("Element", i, "length:", realStorageProof[i].length);
            
            try this.parseProofElement(realStorageProof[i]) returns (bool success) {
                console.log("  ✅ Element", i, "RLP parsing OK");
            } catch {
                console.log("  ❌ Element", i, "RLP parsing FAILED");
            }
        }
    }
    
    function parseProofElement(bytes calldata element) external pure returns (bool) {
        RLPReader.RLPItem[] memory parsed = RLPReader.readList(element);
        return parsed.length > 0;
    }

    // 🎯 DEBUG 6: Test expected value encoding
    function test_06_ExpectedValueEncoding() public {
        console.log("\n🔍 === STEP 6: EXPECTED VALUE ENCODING ===");
        
        // From your eth_getProof: "value": "0x1" 
        // This should be RLP encoded as just 0x01
        
        bytes memory expectedRLP = hex"01";
        console.log("Expected RLP for value 1 (true):");
        console.logBytes(expectedRLP);
        
        bytes32 expectedValue = bytes32(uint256(1));
        console.log("Expected value as bytes32:");
        console.logBytes32(expectedValue);
        
        // Test the encoding logic from SimpleVerifier
        bytes memory encodedValue;
        if (expectedValue == bytes32(uint256(1))) {
            encodedValue = hex"01";
        }
        
        console.log("Encoded value matches expected:", keccak256(encodedValue) == keccak256(expectedRLP));
    }
        console.log("=== DEBUG INFO ===");
        console.log("Test Contract:", TEST_CONTRACT);
        console.logBytes32(TEST_STATE_ROOT);
        
        // Calculate storage key for slot 0
        bytes32 storageKey = keccak256(abi.encodePacked(bytes32(0)));
        console.log("Storage key for slot 0:");
        console.logBytes32(storageKey);
        
        // Expected value encoding for true
        bytes memory expectedValue = hex"01";
        console.log("Expected RLP value for true:", expectedValue.length);
    }
}