// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * 🛡️ SIMPLE STORAGE PROOF VERIFIER
 * 
 * This contract demonstrates how to verify storage proofs from another chain.
 * It uses a simplified approach to understand the core concepts.
 */
contract SimpleVerifier {
    
    struct StorageProof {
        bytes32 stateRoot;        // Block's state root from source chain
        address sourceContract;   // Contract address on source chain
        uint256 sourceChainId;    // Chain ID where proof originated
        uint256 blockNumber;      // Block number where state existed
        bytes32 storageKey;       // Storage slot key
        bytes32 storageValue;     // Storage slot value
        bytes32[] accountProof;   // Proof that account exists in state trie
        bytes32[] storageProof;   // Proof that storage exists in account
    }
    
    // Track verified proofs to prevent replay attacks
    mapping(bytes32 => bool) public verifiedProofs;
    
    // Store verified states for querying
    mapping(bytes32 => StorageProof) public verifiedStates;
    
    event ProofVerified(
        bytes32 indexed proofId,
        address indexed sourceContract,
        uint256 indexed sourceChainId,
        bool verificationResult
    );
    
    /**
     * 🎯 VERIFY STORAGE PROOF (Simplified Version)
     * 
     * In a full implementation, this would use Patricia Merkle Trie verification.
     * For our proof of concept, we do basic validation to understand the flow.
     */
    function verifyStorageProof(
        StorageProof calldata proof
    ) external returns (bool) {
        // Create unique proof ID to prevent replays
        bytes32 proofId = keccak256(abi.encodePacked(
            proof.stateRoot,
            proof.sourceContract,
            proof.sourceChainId,
            proof.blockNumber,
            proof.storageKey
        ));
        
        require(!verifiedProofs[proofId], "Proof already used");
        
        // 🎯 SIMPLIFIED VERIFICATION LOGIC
        // In production, this would verify the full Merkle Patricia Trie
        bool isValid = (
            proof.stateRoot != bytes32(0) &&
            proof.sourceContract != address(0) &&
            proof.sourceChainId != 0 &&
            proof.accountProof.length > 0 &&
            proof.storageProof.length > 0
        );
        
        if (isValid) {
            verifiedProofs[proofId] = true;
            verifiedStates[proofId] = proof;
        }
        
        emit ProofVerified(
            proofId,
            proof.sourceContract,
            proof.sourceChainId,
            isValid
        );
        
        return isValid;
    }
    
    /**
     * 🔍 Get verification status
     */
    function isProofVerified(bytes32 proofId) external view returns (bool) {
        return verifiedProofs[proofId];
    }
    
    /**
     * 📊 Get verified state details
     */
    function getVerifiedState(bytes32 proofId) external view returns (StorageProof memory) {
        require(verifiedProofs[proofId], "Proof not verified");
        return verifiedStates[proofId];
    }
}
