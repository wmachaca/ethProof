// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * 📚 COMPLETE RLP READER LIBRARY
 * 
 * Full implementation of RLP (Recursive Length Prefix) decoding
 * Required for proper Merkle Patricia Trie verification
 */
library RLPReader {
    uint8 constant STRING_SHORT_START = 0x80;
    uint8 constant STRING_LONG_START = 0xb8;
    uint8 constant LIST_SHORT_START = 0xc0;
    uint8 constant LIST_LONG_START = 0xf8;

    struct RLPItem {
        uint len;
        uint memPtr;
    }

    /**
     * 🔧 Convert bytes to RLP item
     */
    function toRlpItem(bytes memory item) internal pure returns (RLPItem memory) {
        uint memPtr;
        assembly {
            memPtr := add(item, 0x20)
        }
        return RLPItem(item.length, memPtr);
    }

    /**
     * 📊 Check if RLP item is a list
     */
    function isList(RLPItem memory item) internal pure returns (bool) {
        if (item.len == 0) return false;

        uint8 byte0;
        uint memPtr = item.memPtr;
        assembly {
            byte0 := byte(0, mload(memPtr))
        }

        return byte0 >= LIST_SHORT_START;
    }

    /**
     * 📝 Convert RLP item to bytes
     */
    function toBytes(RLPItem memory item) internal pure returns (bytes memory) {
        require(item.len > 0, "Empty RLP item");
        
        uint8 byte0;
        assembly {
            byte0 := byte(0, mload(item.memPtr))
        }

        if (byte0 < STRING_SHORT_START) {
            // Single byte
            bytes memory result = new bytes(1);
            assembly {
                mstore(add(result, 0x20), byte0)
            }
            return result;
        } else if (byte0 < STRING_LONG_START) {
            // Short string
            uint256 strLen = byte0 - STRING_SHORT_START;
            return _copyToBytes(item.memPtr + 1, strLen);
        } else if (byte0 < LIST_SHORT_START) {
            // Long string
            uint256 lenOfStrLen = byte0 - STRING_LONG_START;
            uint256 strLen = _toUint(item.memPtr + 1, lenOfStrLen);
            return _copyToBytes(item.memPtr + 1 + lenOfStrLen, strLen);
        } else {
            revert("RLP item is a list, not bytes");
        }
    }

    /**
     * 🔢 Convert RLP item to uint
     */
    function toUint(RLPItem memory item) internal pure returns (uint256) {
        bytes memory data = toBytes(item);
        return _bytesToUint(data);
    }

    /**
     * 📋 Convert RLP item to list of RLP items
     */
    function toList(RLPItem memory item) internal pure returns (RLPItem[] memory) {
        require(isList(item), "RLP item is not a list");

        uint8 byte0;
        assembly {
            byte0 := byte(0, mload(item.memPtr))
        }

        uint256 listLen;
        uint256 listPtr;

        if (byte0 < LIST_LONG_START) {
            // Short list
            listLen = byte0 - LIST_SHORT_START;
            listPtr = item.memPtr + 1;
        } else {
            // Long list
            uint256 lenOfListLen = byte0 - LIST_LONG_START;
            listLen = _toUint(item.memPtr + 1, lenOfListLen);
            listPtr = item.memPtr + 1 + lenOfListLen;
        }

        return _toList(listPtr, listLen);
    }

    /**
     * 🔧 INTERNAL: Copy memory to bytes
     */
    function _copyToBytes(uint256 ptr, uint256 len) private pure returns (bytes memory) {
        bytes memory result = new bytes(len);
        uint256 destPtr;
        assembly {
            destPtr := add(result, 0x20)
        }
        _memcopy(ptr, destPtr, len);
        return result;
    }

    /**
     * 🔧 INTERNAL: Convert bytes to uint
     */
    function _bytesToUint(bytes memory data) private pure returns (uint256) {
        if (data.length == 0) return 0;
        
        uint256 result;
        assembly {
            result := mload(add(data, 0x20))
        }
        
        // Shift right to remove unused bytes
        result = result >> (8 * (32 - data.length));
        return result;
    }

    /**
     * 🔧 INTERNAL: Read uint from memory
     */
    function _toUint(uint256 ptr, uint256 len) private pure returns (uint256) {
        require(len <= 32, "Length too long");
        
        uint256 result;
        assembly {
            result := mload(ptr)
        }
        
        result = result >> (8 * (32 - len));
        return result;
    }

    /**
     * 🔧 INTERNAL: Parse list from memory
     */
    function _toList(uint256 ptr, uint256 len) private pure returns (RLPItem[] memory) {
        RLPItem[] memory result = new RLPItem[](len);
        uint256 currentPtr = ptr;
        uint256 endPtr = ptr + len;
        uint256 itemCount = 0;

        while (currentPtr < endPtr && itemCount < len) {
            uint256 itemLen = _itemLength(currentPtr);
            result[itemCount] = RLPItem(itemLen, currentPtr);
            currentPtr += itemLen;
            itemCount++;
        }

        // Resize array to actual item count
        assembly {
            mstore(result, itemCount)
        }

        return result;
    }

    /**
     * 🔧 INTERNAL: Get length of RLP item at pointer
     */
    function _itemLength(uint256 ptr) private pure returns (uint256) {
        uint8 byte0;
        assembly {
            byte0 := byte(0, mload(ptr))
        }

        if (byte0 < STRING_SHORT_START) {
            return 1;
        } else if (byte0 < STRING_LONG_START) {
            return 1 + (byte0 - STRING_SHORT_START);
        } else if (byte0 < LIST_SHORT_START) {
            uint256 lenOfStrLen = byte0 - STRING_LONG_START;
            uint256 strLen = _toUint(ptr + 1, lenOfStrLen);
            return 1 + lenOfStrLen + strLen;
        } else if (byte0 < LIST_LONG_START) {
            return 1 + (byte0 - LIST_SHORT_START);
        } else {
            uint256 lenOfListLen = byte0 - LIST_LONG_START;
            uint256 listLen = _toUint(ptr + 1, lenOfListLen);
            return 1 + lenOfListLen + listLen;
        }
    }

    /**
     * 🔧 INTERNAL: Memory copy
     */
    function _memcopy(uint256 src, uint256 dest, uint256 len) private pure {
        // Copy word by word
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        if (len > 0) {
            uint256 mask = 256 ** (32 - len) - 1;
            assembly {
                let srcpart := and(mload(src), not(mask))
                let destpart := and(mload(dest), mask)
                mstore(dest, or(destpart, srcpart))
            }
        }
    }
}
