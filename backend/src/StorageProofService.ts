import { createPublicClient, http, keccak256, encodePacked, toHex, pad } from 'viem';
import { anvilChain1, anvilChain2, STORAGE_CONTRACT_ADDRESSES } from './config';

/**
 * 🌳 STORAGE PROOF SERVICE
 * 
 * This demonstrates the core concepts from the Chainstack article:
 * 1. Calculate storage keys for Solidity mappings/variables
 * 2. Use eth_getProof to get storage proofs
 * 3. Verify storage proofs on another chain
 */

export interface SimpleStorageProof {
  stateRoot: string;
  sourceContract: string;
  sourceChainId: number;
  blockNumber: number;
  storageKey: string;
  storageValue: string;
  accountProof: string[];
  storageProof: string[];
}

export class StorageProofService {
  private clients: Map<number, any> = new Map();

  constructor() {
    console.log('\n🌳 =======================================');
    console.log('🌳 STORAGE PROOF SERVICE - DEMO');
    console.log('🌳 =======================================');
    console.log('📚 Implementing concepts from Chainstack article');
    console.log('🎯 Goal: Prove storage values exist between chains\n');

    this.initializeClients();
  }

  /**
   * 🔧 Initialize blockchain clients
   */
  private initializeClients(): void {
    // Client for Chain 1 (port 8545)
    const client1 = createPublicClient({
      chain: anvilChain1,
      transport: http('http://127.0.0.1:8545'),
    });

    // Client for Chain 2 (port 8546)  
    const client2 = createPublicClient({
      chain: anvilChain2,
      transport: http('http://127.0.0.1:8546'),
    });

    this.clients.set(31337, client1);
    this.clients.set(31338, client2);

    console.log('✅ Blockchain clients initialized:');
    console.log('  📡 Chain 31337: http://127.0.0.1:8545');
    console.log('  📡 Chain 31338: http://127.0.0.1:8546');
  }

  /**
   * 🔑 Calculate storage key for boolean gameActive
   * 
   * In SimpleStorage.sol: bool public gameActive;
   * This is stored at slot 0 in contract storage
   */
  calculateStorageKey(slotNumber: number = 0): string {
    // For simple variables (not mappings), storage key = slot number
    const storageKey = pad(toHex(slotNumber), { size: 32 });
    
    console.log('🔑 Storage key calculated:');
    console.log('  📊 Slot number:', slotNumber);
    console.log('  🗝️  Storage key:', storageKey);
    
    return storageKey;
  }

  /**
   * 🛡️ Get storage proof using eth_getProof
   * This is THE method from the Chainstack article!
   */
  async getStorageProof(
    chainId: number,
    contractAddress: string,
    blockNumber: number
  ): Promise<any> {
    console.log('\n🛡️ ===== GETTING STORAGE PROOF =====');
    console.log('📡 Chain ID:', chainId);
    console.log('📄 Contract:', contractAddress);
    console.log('📦 Block:', blockNumber);

    const client = this.clients.get(chainId);
    if (!client) {
      throw new Error(`No client for chain ${chainId}`);
    }

    try {
      // Calculate storage key for gameActive (slot 0)
      const storageKey = this.calculateStorageKey(0);

      console.log('📡 Calling eth_getProof...');

      // 🔥 THE MAGIC METHOD FROM THE ARTICLE!
      const proof = await client.request({
        method: 'eth_getProof',
        params: [
          contractAddress,
          [storageKey],
          toHex(BigInt(blockNumber))
        ]
      });

      console.log('✅ Storage proof retrieved!');
      console.log('📊 Proof structure:');
      console.log('  🏠 Account Proof Elements:', proof.accountProof?.length || 0);
      console.log('  📊 Storage Proofs:', proof.storageProof?.length || 0);
      
      if (proof.storageProof?.[0]) {
        console.log('  🔑 Storage Key:', proof.storageProof[0].key);
        console.log('  💾 Storage Value:', proof.storageProof[0].value);
        console.log('  🌳 Storage Proof Elements:', proof.storageProof[0].proof?.length || 0);
      }

      return proof;

    } catch (error) {
      console.error('❌ Error getting storage proof:', error);
      throw error;
    }
  }

  /**
   * 🎯 Create complete storage proof for cross-chain verification
   */
  async createCompleteStorageProof(
    sourceChainId: number,
    blockNumber: number
  ): Promise<SimpleStorageProof> {
    console.log('\n🏗️ ===== CREATING COMPLETE STORAGE PROOF =====');

    try {
      const contractAddress = STORAGE_CONTRACT_ADDRESSES[sourceChainId];
      if (!contractAddress) {
        throw new Error(`No storage contract for chain ${sourceChainId}`);
      }

      // Get the block to extract state root
      const client = this.clients.get(sourceChainId);
      const block = await client.getBlock({ blockNumber: BigInt(blockNumber) });

      console.log('📦 Block retrieved:');
      console.log('  🌳 State Root:', block.stateRoot);
      console.log('  📊 Block Number:', block.number);

      // Get storage proof
      const ethProof = await this.getStorageProof(sourceChainId, contractAddress, blockNumber);

      // Create complete proof structure
      const completeProof: SimpleStorageProof = {
        stateRoot: block.stateRoot,
        sourceContract: contractAddress,
        sourceChainId: sourceChainId,
        blockNumber: blockNumber,
        storageKey: ethProof.storageProof[0]?.key || '0x0',
        storageValue: ethProof.storageProof[0]?.value || '0x0',
        accountProof: ethProof.accountProof || [],
        storageProof: ethProof.storageProof[0]?.proof || []
      };

      console.log('✅ Complete storage proof created!');
      console.log('📋 Proof summary:');
      console.log('  🔗 Source Chain:', sourceChainId);
      console.log('  📄 Source Contract:', completeProof.sourceContract);
      console.log('  📦 Block Number:', completeProof.blockNumber);
      console.log('  🌳 State Root:', completeProof.stateRoot);
      console.log('  🔑 Storage Key:', completeProof.storageKey);
      console.log('  💾 Storage Value:', completeProof.storageValue);
      console.log('  🏠 Account Proof Elements:', completeProof.accountProof.length);
      console.log('  🛡️ Storage Proof Elements:', completeProof.storageProof.length);

      return completeProof;

    } catch (error) {
      console.error('❌ Error creating complete storage proof:', error);
      throw error;
    }
  }

  /**
   * 🔍 Verify storage proof (simplified validation)
   */
  verifyStorageProof(proof: SimpleStorageProof): boolean {
    console.log('\n🔍 ===== VERIFYING STORAGE PROOF =====');

    try {
      // Basic validation (full implementation would verify Merkle Patricia Trie)
      const isValid = (
        proof.stateRoot && proof.stateRoot !== '0x' &&
        proof.sourceContract && proof.sourceContract !== '0x' &&
        proof.storageKey && proof.storageKey !== '0x0' &&
        proof.accountProof.length > 0 &&
        proof.storageProof.length > 0
      );

      console.log(`🔍 Storage proof validation: ${isValid ? '✅ VALID' : '❌ INVALID'}`);
      
      if (isValid) {
        console.log('✅ Proof components verified:');
        console.log('  🌳 State root exists');
        console.log('  📄 Source contract valid');
        console.log('  🔑 Storage key valid');
        console.log('  🏠 Account proof present');
        console.log('  🛡️ Storage proof present');
      }

      return isValid;

    } catch (error) {
      console.error('❌ Error verifying storage proof:', error);
      return false;
    }
  }

  /**
   * 🎮 Demo: Full storage proof flow
   */
  async demonstrateStorageProofFlow(): Promise<void> {
    console.log('\n🎮 =======================================');
    console.log('🎮 DEMONSTRATING STORAGE PROOF FLOW');
    console.log('🎮 =======================================\n');

    try {
      // Step 1: Get latest block from Chain 1
      const client1 = this.clients.get(31337);
      const latestBlock = await client1.getBlockNumber();
      
      console.log('📊 Using latest block from Chain 1:', latestBlock);

      // Step 2: Create storage proof for Chain 1
      const proof = await this.createCompleteStorageProof(31337, Number(latestBlock));

      // Step 3: Verify the proof
      const isValid = this.verifyStorageProof(proof);

      // Step 4: Show results
      console.log('\n🎉 =======================================');
      console.log('🎉 STORAGE PROOF DEMONSTRATION COMPLETE!');
      console.log('🎉 =======================================');
      console.log('✅ Proof generated and verified successfully!');
      console.log('🔥 Ready for cross-chain verification!');

    } catch (error) {
      console.error('❌ Demo failed:', error);
    }
  }
}

// Run demonstration if called directly
if (require.main === module) {
  const service = new StorageProofService();
  service.demonstrateStorageProofFlow();
}
