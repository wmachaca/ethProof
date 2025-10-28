// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MerkleTrie } from "@eth-optimism/contracts-bedrock/libraries/trie/MerkleTrie.sol";
import { RLPReader } from "@eth-optimism/contracts-bedrock/libraries/rlp/RLPReader.sol";
import "forge-std/console.sol";

/**
 * 🔧 DEBUG VERSION - Step-by-step verification with console logs
 */
contract DebugSimpleVerifier {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    // Simple proof structure
    struct SimpleProof {
        bytes32 stateRoot;
        address contractAddress;
        bytes32 storageSlot;
        bytes32 expectedValue;
        bytes[] accountProof;
        bytes[] storageProof;
    }

    // Events to see what happens
    event DebugStep(string step, bool success);
    event ProofVerified(address contractAddress, bytes32 slot, bool success);

    function verifySimpleProof(SimpleProof calldata proof) external returns (bool) {
        console.log("=== STARTING VERIFICATION ===");
        console.logBytes32(proof.stateRoot);
        console.log("Contract Address:", proof.contractAddress);
        console.logBytes32(proof.storageSlot);
        console.logBytes32(proof.expectedValue);
        console.log("Account Proof Elements:", proof.accountProof.length);
        console.log("Storage Proof Elements:", proof.storageProof.length);
        
        emit DebugStep("INPUT_VALIDATION", true);
        
        // Step 1: Basic validation
        require(proof.stateRoot != bytes32(0), "Invalid state root");
        require(proof.contractAddress != address(0), "Invalid contract address");
        require(proof.accountProof.length > 0, "Empty account proof");
        require(proof.storageProof.length > 0, "Empty storage proof");
        
        console.log("Basic validation passed");
        emit DebugStep("BASIC_VALIDATION", true);
        
        // Step 2: Try to get account data (this is likely where it fails)
        console.log("=== TRYING TO GET ACCOUNT DATA ===");
        bytes memory accountKey = abi.encodePacked(proof.contractAddress);
        console.log("Account Key Length:", accountKey.length);
        console.logBytes(accountKey);
        
        bytes memory accountRlp;
        try this.getAccountData(accountKey, proof.accountProof, proof.stateRoot) returns (bytes memory result) {
            accountRlp = result;
            console.log("Account data retrieved successfully!");
            console.log("Account RLP Length:", accountRlp.length);
            emit DebugStep("ACCOUNT_RETRIEVAL", true);
        } catch Error(string memory reason) {
            console.log("Account retrieval failed:");
            console.log(reason);
            emit DebugStep("ACCOUNT_RETRIEVAL", false);
            emit ProofVerified(proof.contractAddress, proof.storageSlot, false);
            return false;
        } catch (bytes memory lowLevelData) {
            console.log("Account retrieval failed with low-level error");
            console.logBytes(lowLevelData);
            emit DebugStep("ACCOUNT_RETRIEVAL", false);
            emit ProofVerified(proof.contractAddress, proof.storageSlot, false);
            return false;
        }
        
        if (accountRlp.length == 0) {
            console.log("Account RLP is empty");
            emit DebugStep("ACCOUNT_CHECK", false);
            emit ProofVerified(proof.contractAddress, proof.storageSlot, false);
            return false;
        }
        
        // Step 3: Parse account RLP
        console.log("=== PARSING ACCOUNT RLP ===");
        RLPReader.RLPItem[] memory accountFields;
        try this.parseAccountRlp(accountRlp) returns (RLPReader.RLPItem[] memory fields) {
            accountFields = fields;
            console.log("Account RLP parsed successfully!");
            console.log("Account Fields Count:", accountFields.length);
            emit DebugStep("ACCOUNT_PARSING", true);
        } catch Error(string memory reason) {
            console.log("Account parsing failed:");
            console.log(reason);
            emit DebugStep("ACCOUNT_PARSING", false);
            emit ProofVerified(proof.contractAddress, proof.storageSlot, false);
            return false;
        }
        
        // Step 4: Extract storage root
        console.log("=== EXTRACTING STORAGE ROOT ===");
        require(accountFields.length >= 3, "Invalid account structure");
        
        bytes memory storageRootBytes = RLPReader.readBytes(accountFields[2]);
        console.log("Storage Root Bytes Length:", storageRootBytes.length);
        
        bytes32 storageRoot;
        assembly {
            storageRoot := mload(add(storageRootBytes, 32))
        }
        console.logBytes32(storageRoot);
        emit DebugStep("STORAGE_ROOT_EXTRACTION", true);
        
        // Step 5: Prepare storage key
        console.log("=== PREPARING STORAGE KEY ===");
        bytes32 storageKey = keccak256(abi.encodePacked(proof.storageSlot));
        console.logBytes32(storageKey);
        
        // Step 6: Prepare expected value (RLP encoded)
        console.log("=== PREPARING EXPECTED VALUE ===");
        bytes memory expectedValueRlp;
        if (proof.expectedValue == bytes32(0)) {
            expectedValueRlp = "";
            console.log("Expected Value: empty (for 0)");
        } else if (proof.expectedValue == bytes32(uint256(1))) {
            expectedValueRlp = hex"01";
            console.log("Expected Value: 0x01 (for true)");
        } else {
            expectedValueRlp = abi.encodePacked(proof.expectedValue);
            console.log("Expected Value: full bytes32");
        }
        console.log("Expected Value RLP Length:", expectedValueRlp.length);
        console.logBytes(expectedValueRlp);
        
        // Step 7: Verify storage proof
        console.log("=== VERIFYING STORAGE PROOF ===");
        bool storageVerified;
        try this.verifyStorageInclusion(
            abi.encodePacked(storageKey),
            expectedValueRlp,
            proof.storageProof,
            storageRoot
        ) returns (bool verified) {
            storageVerified = verified;
            console.log("Storage Verification Result:", verified);
            emit DebugStep("STORAGE_VERIFICATION", verified);
        } catch Error(string memory reason) {
            console.log("Storage verification failed:");
            console.log(reason);
            emit DebugStep("STORAGE_VERIFICATION", false);
            emit ProofVerified(proof.contractAddress, proof.storageSlot, false);
            return false;
        } catch (bytes memory lowLevelData) {
            console.log("Storage verification failed with low-level error");
            console.logBytes(lowLevelData);
            emit DebugStep("STORAGE_VERIFICATION", false);
            emit ProofVerified(proof.contractAddress, proof.storageSlot, false);
            return false;
        }
        
        console.log("=== VERIFICATION COMPLETE ===");
        console.log("Final Result:", storageVerified);
        
        emit ProofVerified(proof.contractAddress, proof.storageSlot, storageVerified);
        return storageVerified;
    }
    
    // External functions for try/catch
    function getAccountData(bytes memory key, bytes[] memory proof, bytes32 root) external pure returns (bytes memory) {
        // 🔧 Let's see exactly what we're trying to prove
        console.log("=== INSIDE getAccountData ===");
        console.log("Key (contract address):");
        console.logBytes(key);
        console.log("Root (state root):");
        console.logBytes32(root);
        console.log("Proof elements count:", proof.length);
        
        for (uint i = 0; i < proof.length; i++) {
            console.log("Proof element", i, "length:", proof[i].length);
            console.logBytes(proof[i]);
        }
        
        // This is where the magic happens - or fails!
        bytes memory result = MerkleTrie.get(key, proof, root);
        
        console.log("MerkleTrie.get() succeeded!");
        console.log("Returned account data length:", result.length);
        console.logBytes(result);
        
        return result;
    }
    
    function parseAccountRlp(bytes memory accountRlp) external pure returns (RLPReader.RLPItem[] memory) {
        return RLPReader.readList(accountRlp);
    }
    
    function verifyStorageInclusion(
        bytes memory key,
        bytes memory value,
        bytes[] memory proof,
        bytes32 root
    ) external pure returns (bool) {
        return MerkleTrie.verifyInclusionProof(key, value, proof, root);
    }
}
