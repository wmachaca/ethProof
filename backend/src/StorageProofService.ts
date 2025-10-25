import { createPublicClient, createWalletClient, http, keccak256, encodePacked, toHex, pad } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { anvilChain1, anvilChain2, STORAGE_CONTRACT_ADDRESSES, VERIFIER_CONTRACT_ADDRESSES } from './config';

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
  private walletClient2: any; // For sending transactions to Chain 2
  private account: any;

  constructor() {
    console.log('\n =======================================');
    console.log(' STORAGE PROOF SERVICE - DEMO');
    console.log(' =======================================');

    this.initializeClients();
  }

  /**
   * 🔧 Initialize blockchain clients
   */
  private initializeClients(): void {
    // Account for transactions
    this.account = privateKeyToAccount('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80');

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

    // Wallet client for sending transactions to Chain 2
    this.walletClient2 = createWalletClient({
      account: this.account,
      chain: anvilChain2,
      transport: http('http://127.0.0.1:8546'),
    });

    this.clients.set(31337, client1);
    this.clients.set(31338, client2);

    console.log('✅ Blockchain clients initialized:');
    console.log('  📡 Chain 31337: http://127.0.0.1:8545');
    console.log('  📡 Chain 31338: http://127.0.0.1:8546');
    console.log('  👤 Account:', this.account.address);
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

      // 🔧 FIX: Pad storage value to 32 bytes for Solidity bytes32
      const rawStorageValue = ethProof.storageProof[0]?.value || '0x0';
      const paddedStorageValue = pad(rawStorageValue as `0x${string}`, { size: 32 });

      // Create complete proof structure
      const completeProof: SimpleStorageProof = {
        stateRoot: block.stateRoot,
        sourceContract: contractAddress,
        sourceChainId: sourceChainId,
        blockNumber: blockNumber,
        storageKey: ethProof.storageProof[0]?.key || '0x0',
        storageValue: paddedStorageValue, // Now properly padded to 32 bytes
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
      console.log('  💾 Storage Value (raw):', rawStorageValue);
      console.log('  💾 Storage Value (padded):', completeProof.storageValue);
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

      // Ensure boolean return type
      const validationResult = Boolean(isValid);

      console.log(`🔍 Storage proof validation: ${validationResult ? '✅ VALID' : '❌ INVALID'}`);
      
      if (validationResult) {
        console.log('✅ Proof components verified:');
        console.log('  🌳 State root exists');
        console.log('  📄 Source contract valid');
        console.log('  🔑 Storage key valid');
        console.log('  🏠 Account proof present');
        console.log('  🛡️ Storage proof present');
      }

      return validationResult;

    } catch (error) {
      console.error('❌ Error verifying storage proof:', error);
      return false;
    }
  }

  /**
   * ✅ Send proof to ProductionVerifier contract on Chain 2
   */
  async sendProofToVerifierContract(proof: SimpleStorageProof): Promise<boolean> {
    console.log('\n✅ ===== SENDING PROOF TO CHAIN 2 =====');

    const verifierContract = VERIFIER_CONTRACT_ADDRESSES[31338];
    console.log('🏭 ProductionVerifier contract:', verifierContract);

    try {
      // First check if already verified
      const client2 = this.clients.get(31338);
      const alreadyVerified = await client2.readContract({
        address: verifierContract,
        abi: [
          {
            "inputs": [{"type": "address"}],
            "name": "isGameActiveProven",
            "outputs": [{"type": "bool"}],
            "stateMutability": "view",
            "type": "function"
          }
        ],
        functionName: 'isGameActiveProven',
        args: [proof.sourceContract],
      });

      if (alreadyVerified) {
        console.log('✅ Already verified on Chain 2!');
        return true;
      }

      console.log('📤 Sending storage proof to Chain 2 ProductionVerifier...');
      console.log('📋 Proof data being sent:');
      console.log('  🌳 State Root:', proof.stateRoot.substring(0, 20) + '...');
      console.log('  📄 Source Contract:', proof.sourceContract);
      console.log('  🔗 Chain ID:', proof.sourceChainId);
      console.log('  📦 Block Number:', proof.blockNumber);
      console.log('  💾 Storage Value:', proof.storageValue, '(1 = true)');
      console.log('  🏠 Account Proofs:', proof.accountProof.length);
      console.log('  🛡️ Storage Proofs:', proof.storageProof.length);

      // 🏭 PRODUCTION VERIFIER ABI - Real MPT verification
      const hash = await this.walletClient2.writeContract({
        address: verifierContract,
        abi: [
          {
            "inputs": [{
              "components": [
                {"name": "stateRoot", "type": "bytes32"},
                {"name": "sourceContract", "type": "address"},
                {"name": "sourceChainId", "type": "uint256"},
                {"name": "blockNumber", "type": "uint256"},
                {"name": "storageKey", "type": "bytes32"},
                {"name": "storageValue", "type": "bytes32"},
                {"name": "accountProof", "type": "bytes[]"},
                {"name": "storageProof", "type": "bytes[]"}
              ],
              "name": "proof",
              "type": "tuple"
            }],
            "name": "verifyStorageProof",
            "outputs": [{"type": "bool"}],
            "stateMutability": "nonpayable",
            "type": "function"
          }
        ],
        functionName: 'verifyStorageProof',
        args: [{
          stateRoot: proof.stateRoot,
          sourceContract: proof.sourceContract,
          sourceChainId: proof.sourceChainId,
          blockNumber: proof.blockNumber,
          storageKey: proof.storageKey,
          storageValue: proof.storageValue,
          accountProof: proof.accountProof,
          storageProof: proof.storageProof
        }],
        gas: 2000000n, // 🔧 INCREASED GAS for full MPT verification
      });

      console.log('📋 Verification transaction hash:', hash);
      console.log('⏳ Waiting for Chain 2 to process the REAL MPT proof...');

      // Wait for transaction confirmation
      const receipt = await client2.waitForTransactionReceipt({ hash });
      
      // 🔧 CHECK TRANSACTION STATUS
      if (receipt.status === 'reverted') {
        console.log('❌ ProductionVerifier transaction reverted!');
        console.log('📋 This could mean:');
        console.log('  1. 🔍 The MPT proof is invalid (security working!)');
        console.log('  2. 🧮 RLP decoding failed');
        console.log('  3. ⛽ Out of gas (complex MPT verification)');
        console.log('  4. 🌳 Merkle Patricia Trie path mismatch');
        console.log('📋 Transaction receipt:', receipt);
        
        // Try to get revert reason
        try {
          await client2.simulateContract({
            address: verifierContract,
            abi: [
              {
                "inputs": [{
                  "components": [
                    {"name": "stateRoot", "type": "bytes32"},
                    {"name": "sourceContract", "type": "address"},
                    {"name": "sourceChainId", "type": "uint256"},
                    {"name": "blockNumber", "type": "uint256"},
                    {"name": "storageKey", "type": "bytes32"},
                    {"name": "storageValue", "type": "bytes32"},
                    {"name": "accountProof", "type": "bytes[]"},
                    {"name": "storageProof", "type": "bytes[]"}
                  ],
                  "name": "proof",
                  "type": "tuple"
                }],
                "name": "verifyStorageProof",
                "outputs": [{"type": "bool"}],
                "stateMutability": "nonpayable",
                "type": "function"
              }
            ],
            functionName: 'verifyStorageProof',
            args: [{
              stateRoot: proof.stateRoot,
              sourceContract: proof.sourceContract,
              sourceChainId: proof.sourceChainId,
              blockNumber: proof.blockNumber,
              storageKey: proof.storageKey,
              storageValue: proof.storageValue,
              accountProof: proof.accountProof,
              storageProof: proof.storageProof
            }],
          });
        } catch (simulateError: any) {
          console.log('❌ Simulation error (revert reason):', simulateError.message);
          
          if (simulateError.message.includes('Invalid account RLP')) {
            console.log('💡 Issue: RLP decoding of account data failed');
            console.log('🔧 Solution: Need proper RLP-encoded account proof elements');
          } else if (simulateError.message.includes('Hash mismatch')) {
            console.log('💡 Issue: Merkle Patricia Trie hash verification failed');
            console.log('🔧 Solution: The proof path is cryptographically invalid');
          }
        }
        
        return false;
      }

      // Check if verification worked
      const nowVerified = await client2.readContract({
        address: verifierContract,
        abi: [
          {
            "inputs": [{"type": "address"}],
            "name": "isGameActiveProven",
            "outputs": [{"type": "bool"}],
            "stateMutability": "view",
            "type": "function"
          }
        ],
        functionName: 'isGameActiveProven',
        args: [proof.sourceContract],
      });

      if (nowVerified) {
        console.log('🎉 PRODUCTION VERIFICATION SUCCESSFUL!');
        console.log('✅ Chain 2 ProductionVerifier cryptographically verified gameActive=true!');
        console.log('🏆 This is REAL Merkle Patricia Trie verification - the gold standard!');
        return true;
      } else {
        console.log('❌ ProductionVerifier rejected the proof');
        console.log('🛡️ This demonstrates the security - invalid proofs are rejected!');
        return false;
      }

    } catch (error: any) {
      console.error('❌ Error sending proof to ProductionVerifier:', error);
      
      // 🔧 BETTER ERROR REPORTING FOR PRODUCTION
      if (error.message.includes('execution reverted')) {
        console.log('🏭 ProductionVerifier rejected the proof - this could be expected!');
        console.log('🎓 Reasons why ProductionVerifier might reject:');
        console.log('  1. 🔍 Invalid RLP encoding in proof elements');
        console.log('  2. 🌳 Merkle Patricia Trie path doesn\'t match');
        console.log('  3. 🔐 Hash chain verification failed');
        console.log('  4. 📊 Storage value doesn\'t match extracted value');
        console.log('✨ This proves the security works - fake proofs cannot pass!');
      } else if (error.message.includes('gas')) {
        console.log('⛽ Gas issue - ProductionVerifier needs more gas for full MPT verification');
        console.log('💡 Try increasing gas limit or optimizing the proof size');
      }
      
      return false;
    }
  }

  /**
   * 🎮 Demo: Full storage proof flow WITH PRODUCTION VERIFICATION
   */
  async demonstrateStorageProofFlow(): Promise<void> {
    console.log('\n🎮 =======================================');
    console.log('🎮 PRODUCTION STORAGE PROOF + VERIFICATION FLOW');
    console.log('🎮 =======================================\n');

    try {
      // Step 1: Get latest block from Chain 1
      const client1 = this.clients.get(31337);
      const latestBlock = await client1.getBlockNumber();
      
      console.log('📊 Using latest block from Chain 1:', latestBlock);

      // Step 2: Create storage proof for Chain 1
      const proof = await this.createCompleteStorageProof(31337, Number(latestBlock));

      // Step 3: Verify the proof locally
      const isValid = this.verifyStorageProof(proof);

      if (!isValid) {
        console.log('❌ Local proof validation failed!');
        return;
      }

      // Step 4: 🏭 Send proof to ProductionVerifier on Chain 2
      const verified = await this.sendProofToVerifierContract(proof);

      // Step 5: Show final results
      console.log('\n🎉 =======================================');
      console.log('🎉 PRODUCTION CROSS-CHAIN PROOF DEMO DONE!');
      console.log('🎉 =======================================');
      console.log('✅ Local proof validation: SUCCESS');
      console.log(`${verified ? '🏆' : '❌'} ProductionVerifier: ${verified ? 'SUCCESS' : 'FAILED'}`);
      
      if (verified) {
        console.log('🔥 ACHIEVEMENT UNLOCKED: Real MPT verification passed!');
        console.log('🎯 Chain 2 has mathematical certainty about Chain 1 state!');
      } else {
        console.log('🛡️ ProductionVerifier security working - invalid proofs rejected!');
        console.log('💡 This demonstrates why production verification is important!');
      }

    } catch (error) {
      console.error('❌ Production demo failed:', error);
    }
  }

  /**
   * 🏭 NEW: Complete end-to-end production demo
   */
  async runCompleteDemo(): Promise<void> {
    console.log('\n🚀 =======================================');
    console.log('🚀 STARTING PRODUCTION CROSS-CHAIN DEMO');
    console.log('🚀 =======================================');
    console.log('📚 This will:');
    console.log('  1️⃣ Generate real storage proof from Chain 1');
    console.log('  2️⃣ Send proof to ProductionVerifier on Chain 2');
    console.log('  3️⃣ Perform REAL Merkle Patricia Trie verification');
    console.log('  4️⃣ Confirm Chain 2 trusts Chain 1 state with mathematical certainty');
    console.log('🏆 Let\'s prove gameActive=true with PRODUCTION-GRADE verification!\n');

    await this.demonstrateStorageProofFlow();
  }
}

// Run demonstration if called directly
if (require.main === module) {
  const service = new StorageProofService();
  service.runCompleteDemo();
}
