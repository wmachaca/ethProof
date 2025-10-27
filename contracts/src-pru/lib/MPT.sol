// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 🔥 USING THE REAL BATTLE-TESTED RLP LIBRARY
import "solidity-rlp/RLPReader.sol";

/**
 * 🌳 PRODUCTION MPT LIBRARY - BASED ON GOLDENGATE
 * 
 * This is based on pipeos-one/goldengate MPT.sol - specifically designed for eth_getProof!
 * Adapted for Solidity 0.8.19 and hamdiallam/solidity-rlp
 * 
 * Original: https://github.com/pipeos-one/goldengate/blob/master/contracts/contracts/lib/MPT.sol
 */
library MPT {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    struct MerkleProof {
        bytes32 expectedRoot;
        bytes key;
        bytes[] proof;
        uint256 keyIndex;
        uint256 proofIndex;
        bytes expectedValue;
    }

    /**
     * 🎯 MAIN MPT VERIFICATION FUNCTION
     * 
     * This is the REAL deal - full Ethereum MPT verification from goldengate!
     */
    function verifyTrieProof(
        MerkleProof memory data
    ) internal pure returns (bool) {
        
        if (data.proofIndex >= data.proof.length) {
            return false;
        }

        bytes memory node = data.proof[data.proofIndex];
        RLPReader.RLPItem memory rlpNode = node.toRlpItem();

        // 🔒 VERIFY NODE HASH MATCHES EXPECTED ROOT
        if (data.keyIndex == 0) {
            require(keccak256(node) == data.expectedRoot, "verifyTrieProof root node hash invalid");
        }
        else if (node.length < 32) {
            RLPReader.RLPItem[] memory nodeList = rlpNode.toList();
            bytes32 root = bytes32(nodeList[0].toUint());
            require(root == data.expectedRoot, "verifyTrieProof < 32");
        }
        else {
            require(keccak256(node) == data.expectedRoot, "verifyTrieProof else");
        }

        uint256 numberItems = 0;
        if (rlpNode.isList()) {
            RLPReader.RLPItem[] memory nodeItems = rlpNode.toList();
            numberItems = nodeItems.length;
        }

        // 🌿 BRANCH NODE (17 items)
        if (numberItems == 17) {
            return verifyTrieProofBranch(data);
        }
        // 🍃 LEAF OR EXTENSION NODE (2 items)
        else if (numberItems == 2) {
            return verifyTrieProofLeafOrExtension(rlpNode, data);
        }

        // Empty value case
        if (data.expectedValue.length == 0) return true;
        return false;
    }

    /**
     * 🌿 VERIFY BRANCH NODE (16 children + optional value)
     */
    function verifyTrieProofBranch(
        MerkleProof memory data
    ) internal pure returns (bool) {
        
        bytes memory node = data.proof[data.proofIndex];
        RLPReader.RLPItem[] memory nodeItems = node.toRlpItem().toList();

        // If we've consumed all key nibbles, check the value at index 16
        if (data.keyIndex >= data.key.length) {
            bytes memory item = nodeItems[16].toBytes();
            if (keccak256(item) == keccak256(data.expectedValue)) {
                return true;
            }
        }
        else {
            // Get the next nibble and follow that branch
            uint256 index = uint256(uint8(data.key[data.keyIndex]));
            bytes memory nextNodeBytes = nodeItems[index].toBytes();

            if (nextNodeBytes.length > 0) {
                data.expectedRoot = bytesToBytes32(nextNodeBytes);
                data.keyIndex += 1;
                data.proofIndex += 1;
                return verifyTrieProof(data);
            }
        }

        // Handle empty expected value
        if (data.expectedValue.length == 0) return true;
        return false;
    }

    /**
     * 🍃 VERIFY LEAF OR EXTENSION NODE
     */
    function verifyTrieProofLeafOrExtension(
        RLPReader.RLPItem memory rlpNode,
        MerkleProof memory data
    ) internal pure returns (bool) {
        
        RLPReader.RLPItem[] memory nodeItems = rlpNode.toList();
        bytes memory nodekey = nodeItems[0].toBytes();
        bytes memory nodevalue = nodeItems[1].toBytes();
        
        uint256 prefix;
        assembly {
            let first := shr(248, mload(add(nodekey, 32)))
            prefix := shr(4, first)
        }

        if (prefix == 2) {
            // 🍃 LEAF NODE (EVEN LENGTH)
            uint256 length = nodekey.length - 1;
            bytes memory actualKey = sliceTransform(nodekey, 1, length, false);
            bytes memory restKey = sliceTransform(data.key, data.keyIndex, length, false);
            
            if (keccak256(data.expectedValue) == keccak256(nodevalue)) {
                if (keccak256(actualKey) == keccak256(restKey)) return true;
                if (keccak256(expandKeyEven(actualKey)) == keccak256(restKey)) return true;
            }
        }
        else if (prefix == 3) {
            // 🍃 LEAF NODE (ODD LENGTH)
            bytes memory actualKey = sliceTransform(nodekey, 0, nodekey.length, true);
            bytes memory restKey = sliceTransform(data.key, data.keyIndex, data.key.length - data.keyIndex, false);
            
            if (keccak256(data.expectedValue) == keccak256(nodevalue)) {
                if (keccak256(actualKey) == keccak256(restKey)) return true;
                if (keccak256(expandKeyOdd(actualKey)) == keccak256(restKey)) return true;
            }
        }
        else if (prefix == 0) {
            // 🔗 EXTENSION NODE (EVEN LENGTH)
            uint256 extensionLength = nodekey.length - 1;
            bytes memory sharedNibbles = sliceTransform(nodekey, 1, extensionLength, false);
            bytes memory restKey = sliceTransform(data.key, data.keyIndex, extensionLength, false);
            
            if (keccak256(sharedNibbles) == keccak256(restKey) ||
                keccak256(expandKeyEven(sharedNibbles)) == keccak256(restKey)) {
                
                data.expectedRoot = bytesToBytes32(nodevalue);
                data.keyIndex += extensionLength;
                data.proofIndex += 1;
                return verifyTrieProof(data);
            }
        }
        else if (prefix == 1) {
            // 🔗 EXTENSION NODE (ODD LENGTH)
            uint256 extensionLength = nodekey.length;
            bytes memory sharedNibbles = sliceTransform(nodekey, 0, extensionLength, true);
            bytes memory restKey = sliceTransform(data.key, data.keyIndex, extensionLength, false);
            
            if (keccak256(sharedNibbles) == keccak256(restKey) ||
                keccak256(expandKeyEven(sharedNibbles)) == keccak256(restKey)) {
                
                data.expectedRoot = bytesToBytes32(nodevalue);
                data.keyIndex += extensionLength;
                data.proofIndex += 1;
                return verifyTrieProof(data);
            }
        }
        else {
            revert("Invalid proof");
        }
        
        // Handle empty expected value
        if (data.expectedValue.length == 0) return true;
        return false;
    }

    /**
     * 🔧 HELPER FUNCTIONS FROM GOLDENGATE
     */
    function bytesToBytes32(bytes memory data) internal pure returns(bytes32 part) {
        if (data.length == 0) return bytes32(0);
        assembly {
            part := mload(add(data, 32))
        }
    }

    function sliceTransform(
        bytes memory data,
        uint256 start,
        uint256 length,
        bool removeFirstNibble
    ) internal pure returns(bytes memory) {
        bytes memory newdata = new bytes(length);
        
        assembly {
            let src := add(add(data, 32), start)
            let dest := add(newdata, 32)
            
            if removeFirstNibble {
                let firstByte := byte(0, mload(src))
                mstore8(dest, and(firstByte, 0x0F))
                src := add(src, 1)
                dest := add(dest, 1)
                length := sub(length, 1)
            }
            
            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                mstore8(add(dest, i), byte(0, mload(add(src, i))))
            }
        }
        
        return newdata;
    }

    function getNibbles(bytes1 b) internal pure returns (bytes1 nibble1, bytes1 nibble2) {
        assembly {
            nibble1 := shr(4, b)
            nibble2 := and(b, 0x0F)
        }
    }

    function expandKeyEven(bytes memory data) internal pure returns (bytes memory) {
        uint256 length = data.length * 2;
        bytes memory expanded = new bytes(length);

        for (uint256 i = 0; i < data.length; i++) {
            (bytes1 nibble1, bytes1 nibble2) = getNibbles(data[i]);
            expanded[i * 2] = nibble1;
            expanded[i * 2 + 1] = nibble2;
        }
        return expanded;
    }

    function expandKeyOdd(bytes memory data) internal pure returns (bytes memory) {
        uint256 length = data.length * 2 - 1;
        bytes memory expanded = new bytes(length);
        expanded[0] = data[0];

        for (uint256 i = 1; i < data.length; i++) {
            (bytes1 nibble1, bytes1 nibble2) = getNibbles(data[i]);
            expanded[i * 2 - 1] = nibble1;
            expanded[i * 2] = nibble2;
        }
        return expanded;
    }
}
