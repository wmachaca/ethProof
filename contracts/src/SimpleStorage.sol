// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * 🎯 SIMPLE STORAGE CONTRACT
 * 
 * This contract demonstrates the basic concept:
 * - Stores a boolean value that can be proven on another chain
 * - When state changes, we can generate storage proofs
 * - Other chains can verify this state existed at a specific block
 */
contract SimpleStorage {
    // 📊 This is the state we'll prove exists on another chain!
    bool public gameActive;
    uint256 public lastUpdatedBlock;
    address public lastUpdater;
    
    // Track all state changes for easy querying
    mapping(uint256 => bool) public stateAtBlock;
    
    event StateChanged(
        bool indexed newState,
        uint256 indexed blockNumber,
        address indexed updater
    );
    
    constructor() {
        gameActive = false;
        lastUpdatedBlock = block.number;
        lastUpdater = msg.sender;
        
        // Record initial state
        stateAtBlock[block.number] = gameActive;
    }
    
    /**
     * 🎮 Change the game state (this creates provable storage changes!)
     */
    function setGameActive(bool _active) external {
        gameActive = _active;
        lastUpdatedBlock = block.number;
        lastUpdater = msg.sender;
        
        // Record state at this block (for easy lookup)
        stateAtBlock[block.number] = _active;
        
        emit StateChanged(_active, block.number, msg.sender);
    }
    
    /**
     * 🔍 Get current state info
     */
    function getStateInfo() external view returns (
        bool active,
        uint256 blockNumber,
        address updater
    ) {
        return (gameActive, lastUpdatedBlock, lastUpdater);
    }
}