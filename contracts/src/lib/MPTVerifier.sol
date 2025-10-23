// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./RLPReader.sol";

/**
 * 🌳 MERKLE PATRICIA TRIE VERIFIER LIBRARY
 * 
 * This implements the core MPT verification logic equivalent to:
 * HexaryTrie.get_from_proof() from the Python py-trie library
 * 
 * Based on Ethereum's Merkle Patricia Trie specification
 */
library MPTVerifier {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    // Node types in Merkle Patricia Trie
    uint8 constant NODE_TYPE_BRANCH = 0;
    uint8 constant NODE_TYPE_LEAF = 1;
    uint8 constant NODE_TYPE_EXTENSION = 2;

    /**
     * 🔥 MAIN MPT VERIFICATION FUNCTION
     * 
     * This is the Solidity equivalent of Python's:
     * HexaryTrie.get_from_proof(root, key, proof_nodes)
     * 
     * @param proof Array of RLP-encoded trie nodes
     * @param root The trie root hash
     * @param key The key we're proving (already hashed)
     * @return The RLP-encoded value at the key, or empty bytes if not found
     */
    function verifyMPTProof(
        bytes[] memory proof,
        bytes32 root,
        bytes32 key
    ) internal pure returns (bytes memory) {
        
        if (proof.length == 0) {
            return new bytes(0);
        }

        bytes32 currentNodeHash = root;
        uint256 keyIndex = 0;
        bytes memory keyBytes = abi.encodePacked(key);
        
        // Traverse the proof path
        for (uint256 i = 0; i < proof.length; i++) {
            bytes memory currentNode = proof[i];
            
            // Verify the node hash matches what we expect
            if (keccak256(currentNode) != currentNodeHash) {
                return new bytes(0); // Hash mismatch - invalid proof
            }
            
            // RLP decode the node
            RLPReader.RLPItem[] memory nodeItems = currentNode.toRlpItem().toList();
            
            if (nodeItems.length == 17) {
                // 🌿 BRANCH NODE - has 16 children + optional value
                currentNodeHash = _processBranchNode(nodeItems, keyBytes, keyIndex);
                keyIndex++;
                
            } else if (nodeItems.length == 2) {
                // 🍃 LEAF or EXTENSION NODE - has path + value/hash
                (bool isLeaf, uint256 pathLength, bytes32 nextHash, bytes memory value) = 
                    _processLeafOrExtensionNode(nodeItems, keyBytes, keyIndex);
                
                if (isLeaf) {
                    // We've reached a leaf - this should be the final value
                    if (keyIndex + pathLength == keyBytes.length * 2) {
                        return value; // Found the value!
                    } else {
                        return new bytes(0); // Path doesn't match completely
                    }
                } else {
                    // Extension node - continue with next hash
                    currentNodeHash = nextHash;
                    keyIndex += pathLength;
                }
            } else {
                return new bytes(0); // Invalid node structure
            }
            
            // If we've consumed the entire key, we should have found the value
            if (keyIndex >= keyBytes.length * 2) {
                break;
            }
        }
        
        return new bytes(0); // Proof incomplete or value not found
    }

    /**
     * 🌿 PROCESS BRANCH NODE
     * 
     * Branch nodes have 16 children (one for each hex digit) plus an optional value
     * Structure: [child0, child1, ..., child15, value]
     */
    function _processBranchNode(
        RLPReader.RLPItem[] memory nodeItems,
        bytes memory key,
        uint256 keyIndex
    ) internal pure returns (bytes32) {
        
        if (keyIndex >= key.length * 2) {
            return bytes32(0); // Key exhausted
        }
        
        // Get the next nibble (4-bit value) from the key
        uint8 nibble = _getNibble(key, keyIndex);
        
        // Get the child hash at this nibble position
        bytes memory childBytes = nodeItems[nibble].toBytes();
        
        if (childBytes.length == 32) {
            // Child is a hash reference
            return bytes32(childBytes);
        } else if (childBytes.length == 0) {
            // No child at this position
            return bytes32(0);
        } else {
            // Embedded node - hash it
            return keccak256(childBytes);
        }
    }

    /**
     * 🍃 PROCESS LEAF OR EXTENSION NODE
     * 
     * Both leaf and extension nodes have structure: [encodedPath, value]
     * Leaf: path ends with terminator, value is the data
     * Extension: path doesn't end with terminator, value is next node hash
     */
    function _processLeafOrExtensionNode(
        RLPReader.RLPItem[] memory nodeItems,
        bytes memory key,
        uint256 keyIndex
    ) internal pure returns (bool isLeaf, uint256 pathLength, bytes32 nextHash, bytes memory value) {
        
        bytes memory encodedPath = nodeItems[0].toBytes();
        bytes memory nodeValue = nodeItems[1].toBytes();
        
        // Decode the path
        (bytes memory pathNibbles, bool terminatesLeaf) = _decodePath(encodedPath);
        
        // Check if the path matches our key
        if (!_pathMatches(pathNibbles, key, keyIndex)) {
            return (false, 0, bytes32(0), new bytes(0)); // Path mismatch
        }
        
        if (terminatesLeaf) {
            // This is a leaf node
            return (true, pathNibbles.length, bytes32(0), nodeValue);
        } else {
            // This is an extension node
            bytes32 hash = bytes32(0);
            if (nodeValue.length == 32) {
                hash = bytes32(nodeValue);
            } else {
                hash = keccak256(nodeValue);
            }
            return (false, pathNibbles.length, hash, new bytes(0));
        }
    }

    /**
     * 🔧 DECODE PATH FROM ENCODED FORMAT
     * 
     * Path encoding in Ethereum MPT:
     * - First nibble encodes: odd/even length + leaf/extension flag
     * - Remaining nibbles are the actual path
     */
    function _decodePath(bytes memory encodedPath) internal pure returns (bytes memory, bool) {
        require(encodedPath.length > 0, "Empty encoded path");
        
        uint8 firstByte = uint8(encodedPath[0]);
        uint8 prefix = firstByte >> 4; // Upper nibble
        
        bool isLeaf = (prefix & 0x02) != 0;
        bool isOddLength = (prefix & 0x01) != 0;
        
        bytes memory pathNibbles;
        
        if (isOddLength) {
            // Odd length: first nibble contains path data
            pathNibbles = new bytes(encodedPath.length * 2 - 1);
            pathNibbles[0] = bytes1(firstByte & 0x0F);
            for (uint256 i = 1; i < encodedPath.length; i++) {
                pathNibbles[i * 2 - 1] = bytes1(uint8(encodedPath[i]) >> 4);
                pathNibbles[i * 2] = bytes1(uint8(encodedPath[i]) & 0x0F);
            }
        } else {
            // Even length: skip first nibble
            pathNibbles = new bytes((encodedPath.length - 1) * 2);
            for (uint256 i = 1; i < encodedPath.length; i++) {
                pathNibbles[(i - 1) * 2] = bytes1(uint8(encodedPath[i]) >> 4);
                pathNibbles[(i - 1) * 2 + 1] = bytes1(uint8(encodedPath[i]) & 0x0F);
            }
        }
        
        return (pathNibbles, isLeaf);
    }

    /**
     * 🔍 CHECK IF PATH MATCHES KEY AT GIVEN INDEX
     */
    function _pathMatches(
        bytes memory pathNibbles,
        bytes memory key,
        uint256 keyIndex
    ) internal pure returns (bool) {
        
        if (keyIndex + pathNibbles.length > key.length * 2) {
            return false; // Path extends beyond key
        }
        
        for (uint256 i = 0; i < pathNibbles.length; i++) {
            uint8 keyNibble = _getNibble(key, keyIndex + i);
            if (uint8(pathNibbles[i]) != keyNibble) {
                return false; // Nibble mismatch
            }
        }
        
        return true;
    }

    /**
     * 🔢 GET NIBBLE (4-bit value) FROM KEY AT GIVEN INDEX
     */
    function _getNibble(bytes memory key, uint256 index) internal pure returns (uint8) {
        uint256 byteIndex = index / 2;
        bool isUpperNibble = (index % 2) == 0;
        
        if (byteIndex >= key.length) {
            return 0;
        }
        
        uint8 byte_value = uint8(key[byteIndex]);
        
        if (isUpperNibble) {
            return byte_value >> 4; // Upper 4 bits
        } else {
            return byte_value & 0x0F; // Lower 4 bits
        }
    }
}
