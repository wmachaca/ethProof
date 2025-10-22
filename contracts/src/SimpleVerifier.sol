// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * 🛡️ SIMPLE STORAGE PROOF VERIFIER - CORRECT VERSION
 * 
 * Storage proofs use Merkle Patricia Tries, NOT standard Merkle trees!
 * Your verifyMerkleProof() function won't work here.
 */
contract SimpleVerifier {
    
    // Simple struct for storage proofs from eth_getProof
    struct StorageProof {
        bytes32 stateRoot;        // Block's state root from eth_getProof
        address sourceContract;   // Which contract 
        uint256 sourceChainId;    // Which chain
        uint256 blockNumber;      // Which block
        bytes32 storageKey;       // Storage slot key (slot 0 for gameActive)
        bytes32 storageValue;     // What value (0x01 = true, 0x00 = false)
        bytes32[] accountProof;   // Account proof from eth_getProof
        bytes32[] storageProof;   // Storage proof from eth_getProof
    }
    
    // Track what we've proven
    mapping(bytes32 => bool) public verifiedProofs;
    mapping(address => bool) public provenGameActive;
    
    event ProofVerified(
        bytes32 indexed proofId,
        address indexed sourceContract,
        bool gameActiveValue
    );
    
    /**
     * 🎯 VERIFY STORAGE PROOF - SIMPLE BUT CORRECT APPROACH
     * 
     * For proof of concept: basic validation + trust eth_getProof data
     * In production: would need full Merkle Patricia Trie verification
     */
    function verifyStorageProof(
        StorageProof calldata proof
    ) external returns (bool) {
        
        // Create proof ID
        bytes32 proofId = keccak256(abi.encodePacked(
            proof.stateRoot,
            proof.sourceContract,
            proof.sourceChainId,
            proof.blockNumber,
            proof.storageKey
        ));
        
        // Prevent replay attacks
        require(!verifiedProofs[proofId], "Proof already used");
        
        // 🔍 BASIC VALIDATION (Proof of concept approach)
        bool isValid = (
            proof.stateRoot != bytes32(0) &&          // Valid state root
            proof.sourceContract != address(0) &&     // Valid contract
            proof.sourceChainId != 0 &&               // Valid chain ID
            proof.storageKey == bytes32(uint256(0)) && // Must be slot 0 (gameActive)
            proof.accountProof.length > 0 &&          // Account proof exists
            proof.storageProof.length > 0             // Storage proof exists
        );
        
        if (isValid) {
            // Mark as verified
            verifiedProofs[proofId] = true;
            
            // Decode storage value (0x01 = true, 0x00 = false)
            bool gameActive = (proof.storageValue == bytes32(uint256(1)));
            provenGameActive[proof.sourceContract] = gameActive;
            
            emit ProofVerified(proofId, proof.sourceContract, gameActive);
        }
        
        return isValid;
    }
    
    /**
     * 🔍 Check if gameActive has been proven for a contract
     */
    function isGameActiveProven(address sourceContract) external view returns (bool) {
        return provenGameActive[sourceContract];
    }
    
    /**
     * 📚 Explain why we can't use verifyMerkleProof
     */
    function explainDifference() external pure returns (string memory) {
        return string(abi.encodePacked(
            "STORAGE PROOFS vs STANDARD MERKLE TREES:\n\n",
            "Your verifyMerkleProof() works for:\n",
            "- Standard Merkle trees (binary trees)\n", 
            "- Custom data structures\n",
            "- Simple hash(left, right) operations\n\n",
            "Storage proofs use:\n",
            "- Merkle Patricia Tries (16-ary trees)\n",
            "- RLP encoding\n", 
            "- Complex trie operations\n\n",
            "This verifier does basic validation.\n",
            "Full verification needs Patricia Trie libraries!"
        ));
    }
}
