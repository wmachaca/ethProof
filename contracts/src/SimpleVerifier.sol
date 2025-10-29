// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MerkleTrie } from "@eth-optimism/contracts-bedrock/libraries/trie/MerkleTrie.sol";
import { RLPReader } from "@eth-optimism/contracts-bedrock/libraries/rlp/RLPReader.sol";
import "forge-std/console.sol";

/**
 * 🚀 SIMPLE CROSS-CHAIN VERIFIER
 * Using Optimism's production-ready libraries
 */
contract SimpleVerifier {
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

  event ProofVerified(address contractAddress, bytes32 slot, bool success);

  /**
   * 🎯 IMPROVED VERIFICATION - Using Optimism's verifyInclusionProof correctly!
   */
  function verifySimpleProof(SimpleProof calldata proof) external returns (bool) {

    // Step 1: Get account data from STATE trie to extract storage root
    bytes memory accountKey  = abi.encodePacked(
      keccak256(abi.encodePacked(proof.contractAddress))
    );

    bytes memory accountRlp = MerkleTrie.get(
      accountKey, // Account address as key
      proof.accountProof, // Account proof
      proof.stateRoot // State root
    );

    // Ensure account exists (get() will revert if account doesn't exist)
    if (accountRlp.length == 0) {
      emit ProofVerified(proof.contractAddress, proof.storageSlot, false);
      return false;
    }

    // Step 2: Parse account RLP to extract storage root
    // Account format: [nonce, balance, storageRoot, codeHash]
    RLPReader.RLPItem[] memory accountFields = RLPReader.readList(accountRlp);
    bytes memory storageRootBytes = RLPReader.readBytes(accountFields[2]);
    bytes32 storageRoot;

    assembly {
      storageRoot := mload(add(storageRootBytes, 32))
    }

    // Step 3: Prepare storage verification data
    bytes32 storageKey = keccak256(abi.encodePacked(proof.storageSlot));

    // Convert expected value to RLP-encoded bytes (as stored in trie)
    bytes memory expectedValueRLP;
    if (proof.expectedValue == bytes32(0)) {
      // Empty storage slot - empty bytes
      expectedValueRLP = "";
    } else if (proof.expectedValue == bytes32(uint256(1))) {
      // For value 1 (true), RLP encoding is just the single byte 0x01
      expectedValueRLP = hex"01";
    } else {
      // For other values, use the minimal non-zero bytes
      expectedValueRLP = abi.encodePacked(proof.expectedValue);
    }

    // Step 4: Verify the EXACT expected value exists in STORAGE trie
    // This is the key improvement - we verify the specific value, not just existence!
    bool storageVerified = MerkleTrie.verifyInclusionProof(
        abi.encodePacked(storageKey),    // Storage key
        expectedValueRLP,                // Expected value (what we want to prove)
        proof.storageProof,              // Storage proof
        storageRoot                      // Storage root from account
    );

    emit ProofVerified(proof.contractAddress, proof.storageSlot, storageVerified);
    return storageVerified;

  }
}