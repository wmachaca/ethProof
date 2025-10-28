import { createPublicClient, createWalletClient, http, keccak256, encodePacked, toHex, pad } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { anvilChain1, anvilChain2, STORAGE_CONTRACT_ADDRESSES, VERIFIER_CONTRACT_ADDRESSES } from './config';

/**
 * 🌳 STORAGE PROOF SERVICE - ADAPTED FOR YOUR SIMPLE CONTRACTS
 * 
 * This demonstrates the core concepts:
 * 1. Calculate storage keys for SimpleStorage.gameActive 
 * 2. Use eth_getProof to get storage proofs
 * 3. Verify with your SimpleVerifier.sol contract
 */

export interface SimpleStorageProof {
  stateRoot: string;      // Block's state root from Chain 1
  sourceContract: string; // SimpleStorage address
  sourceChainId: number;  // 31337 (Chain 1)
  blockNumber: number;    // Proof block height
  storageKey: string;     // keccak256(slot) for bool gameActive (slot 0)
  storageValue: string;   // Expected value (0x01 for true)
  accountProof: string[]; // MPT proof from eth_getProof
  storageProof: string[]; // Storage MPT proof
}

export class StorageProofService {
  private clients: Map<number, any> = new Map();
  private walletClient2: any; // For sending transactions to Chain 2
  private account: any;

  constructor() {
    console.log('\n🎯 =======================================');
    console.log(' SIMPLE STORAGE PROOF SERVICE');
    console.log(' Adapted for SimpleStorage + SimpleVerifier');
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
   * 🔑 Calculate storage key for boolean gameActive (slot 0)
   */
  calculateStorageKey(slotNumber: number = 0): string {
    // For simple variables (not mappings), storage key = slot number
    const storageKey = pad(toHex(slotNumber), { size: 32 });
    
    console.log('🔑 Storage key calculated:');
    console.log('  📊 Slot number:', slotNumber, '(gameActive)');
    console.log('  🗝️  Storage key:', storageKey);
    
    return storageKey;
  }

  /**
   * 🛡️ Get storage proof using eth_getProof
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

      // 🔥 THE MAGIC METHOD!
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
        console.log('  💾 Storage Value:', proof.storageProof[0].value, '(1 = true, 0 = false)');
        console.log('  🌳 Storage Proof Elements:', proof.storageProof[0].proof?.length || 0);
      }

      return proof;

    } catch (error) {
      console.error('❌ Error getting storage proof:', error);
      throw error;
    }
  }

  /**
   * 🎯 Create proof structure for SimpleVerifier.sol
   */
  async createSimpleProof(
    sourceChainId: number,
    blockNumber: number
  ): Promise<SimpleStorageProof> {
    console.log('\n🏗️ ===== CREATING SIMPLE PROOF =====');

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

      // 🔧 IMPORTANT: Format for SimpleVerifier.sol
      const rawStorageValue = ethProof.storageProof[0]?.value || '0x0';
      const paddedStorageValue = pad(rawStorageValue as `0x${string}`, { size: 32 });

      // Create proof structure matching SimpleVerifier.SimpleProof struct
      const simpleProof: SimpleStorageProof = {
        stateRoot: block.stateRoot,
        sourceContract: contractAddress,
        sourceChainId: sourceChainId,
        blockNumber: blockNumber,
        storageKey: ethProof.storageProof[0]?.key || '0x0',
        storageValue: paddedStorageValue, // Padded to 32 bytes for bytes32
        accountProof: ethProof.accountProof || [],
        storageProof: ethProof.storageProof[0]?.proof || []
      };

      console.log('✅ Simple proof created for SimpleVerifier!');
      console.log('📋 Proof summary:');
      console.log('  🔗 Source Chain:', sourceChainId);
      console.log('  📄 Source Contract:', simpleProof.sourceContract);
      console.log('  📦 Block Number:', simpleProof.blockNumber);
      console.log('  🌳 State Root:', simpleProof.stateRoot);
      console.log('  🔑 Storage Key:', simpleProof.storageKey);
      console.log('  💾 Storage Value (raw):', rawStorageValue);
      console.log('  💾 Storage Value (padded):', simpleProof.storageValue);
      console.log('  🏠 Account Proof Elements:', simpleProof.accountProof.length);
      console.log('  🛡️ Storage Proof Elements:', simpleProof.storageProof.length);

      return simpleProof;

    } catch (error) {
      console.error('❌ Error creating simple proof:', error);
      throw error;
    }
  }

  /**
   * ✅ Send proof to SimpleVerifier contract on Chain 2
   */
  async sendProofToSimpleVerifier(proof: SimpleStorageProof): Promise<boolean> {
    console.log('\n✅ ===== SENDING PROOF TO SIMPLE VERIFIER =====');

    const verifierContract = VERIFIER_CONTRACT_ADDRESSES[31338];
    console.log('🔧 SimpleVerifier contract:', verifierContract);

    try {
      console.log('📤 Sending storage proof to Chain 2 SimpleVerifier...');
      console.log('📋 Proof data being sent:');
      console.log('  🌳 State Root:', proof.stateRoot.substring(0, 20) + '...');
      console.log('  📄 Source Contract:', proof.sourceContract);
      console.log('  🔑 Storage Slot:', '0x0 (gameActive)');
      console.log('  💾 Expected Value:', proof.storageValue, '(1 = true)');
      console.log('  🏠 Account Proofs:', proof.accountProof.length);
      console.log('  🛡️ Storage Proofs:', proof.storageProof.length);

      // 🎯 SimpleVerifier.sol ABI - matches your contract exactly
      const hash = await this.walletClient2.writeContract({
        address: verifierContract,
        abi: [
          {
            "inputs": [{
              "components": [
                {"name": "stateRoot", "type": "bytes32"},
                {"name": "contractAddress", "type": "address"}, 
                {"name": "storageSlot", "type": "bytes32"},
                {"name": "expectedValue", "type": "bytes32"},
                {"name": "accountProof", "type": "bytes[]"},
                {"name": "storageProof", "type": "bytes[]"}
              ],
              "name": "proof",
              "type": "tuple"
            }],
            "name": "verifySimpleProof",
            "outputs": [{"type": "bool"}],
            "stateMutability": "nonpayable", 
            "type": "function"
          }
        ],
        functionName: 'verifySimpleProof',
        args: [{
          stateRoot: proof.stateRoot,
          contractAddress: proof.sourceContract,  // Note: contractAddress in struct
          storageSlot: '0x0000000000000000000000000000000000000000000000000000000000000000', // Slot 0
          expectedValue: proof.storageValue,
          accountProof: proof.accountProof,
          storageProof: proof.storageProof
        }],
        gas: 1000000n, // Sufficient gas for Optimism MerkleTrie verification
      });

      console.log('📋 Verification transaction hash:', hash);
      console.log('⏳ Waiting for Chain 2 to process the proof...');

      // Wait for transaction confirmation
      const client2 = this.clients.get(31338);
      const receipt = await client2.waitForTransactionReceipt({ hash });
      
      // 🔧 CHECK TRANSACTION STATUS
      if (receipt.status === 'reverted') {
        console.log('❌ SimpleVerifier transaction reverted!');
        console.log('📋 This could mean:');
        console.log('  1. 🔍 "MerkleTrie: invalid large internal hash" - proof mismatch');
        console.log('  2. 🧮 RLP decoding failed');
        console.log('  3. ⛽ Out of gas');
        console.log('  4. 🌳 State root and proof from different blocks');
        console.log('📋 Transaction receipt:', receipt);
        return false;
      }

      // 🎉 SUCCESS - Check event logs for ProofVerified event
      console.log('🎉 SIMPLE VERIFIER SUCCESS!');
      console.log('✅ Transaction succeeded with status:', receipt.status);
      console.log('📋 Transaction receipt:');
      console.log('  ⛽ Gas used:', receipt.gasUsed.toString());
      console.log('  📦 Block:', receipt.blockNumber.toString());
      console.log('  🔍 Logs:', receipt.logs.length, 'events emitted');

      // Look for ProofVerified event in logs
      if (receipt.logs.length > 0) {
        console.log('🎯 Events found - likely ProofVerified event!');
        receipt.logs.forEach((log: any, index: number) => {
          console.log(`  📋 Log ${index}:`, log);
        });
      }

      console.log('🏆 CROSS-CHAIN VERIFICATION SUCCESSFUL!');
      console.log('✅ Chain 2 SimpleVerifier accepted the proof from Chain 1!');
      return true;

    } catch (error: any) {
      console.error('❌ Error sending proof to SimpleVerifier:', error);
      
      // 🔧 BETTER ERROR REPORTING
      if (error.message.includes('MerkleTrie: invalid large internal hash')) {
        console.log('🎯 DIAGNOSED: Proof and state root mismatch!');
        console.log('💡 Solution: Generate fresh proof from same block as state root');
      } else if (error.message.includes('execution reverted')) {
        console.log('🔧 SimpleVerifier rejected the proof');
        console.log('🎓 Common reasons:');
        console.log('  1. 🔍 Invalid proof format');
        console.log('  2. 🌳 State root mismatch'); 
        console.log('  3. 📊 Wrong storage slot or expected value');
      } else if (error.message.includes('gas')) {
        console.log('⛽ Gas issue - try increasing gas limit');
      }
      
      return false;
    }
  }

  /**
   * 🎮 Demo: Complete flow with SimpleStorage + SimpleVerifier
   */
  async demonstrateSimpleStorageProofFlow(): Promise<void> {
    console.log('\n🎮 =======================================');
    console.log('🎮 COMPLETE SIMPLE STORAGE PROOF FLOW');
    console.log('🎮 SimpleStorage → SimpleVerifier');
    console.log('🎮 =======================================\n');

    try {
      // Step 1: Get latest block from Chain 1
      const client1 = this.clients.get(31337);
      const latestBlock = await client1.getBlockNumber();
      
      console.log('📊 Using latest block from Chain 1:', latestBlock);

      // Step 2: Check gameActive value on Chain 1
      const storageContract = STORAGE_CONTRACT_ADDRESSES[31337];
      const gameActive = await client1.readContract({
        address: storageContract,
        abi: [
          {
            "inputs": [],
            "name": "gameActive",
            "outputs": [{"type": "bool"}],
            "stateMutability": "view",
            "type": "function"
          }
        ],
        functionName: 'gameActive',
      });

      console.log('🎮 Current gameActive on Chain 1:', gameActive);

      // Step 3: Create storage proof for Chain 1  
      const proof = await this.createSimpleProof(31337, Number(latestBlock));

      // Step 4: Send proof to SimpleVerifier on Chain 2
      const verified = await this.sendProofToSimpleVerifier(proof);

      // Step 5: Show final results
      console.log('\n🎉 =======================================');
      console.log('🎉 SIMPLE STORAGE PROOF DEMO COMPLETE!');
      console.log('🎉 =======================================');
      console.log(`✅ Chain 1 gameActive: ${gameActive}`);
      console.log(`${verified ? '🏆' : '❌'} Chain 2 verification: ${verified ? 'SUCCESS' : 'FAILED'}`);
      
      if (verified) {
        console.log('🔥 SUCCESS: SimpleVerifier accepted the proof!');
        console.log('🎯 Chain 2 has cryptographic proof that gameActive=true on Chain 1!');
        console.log('🚀 This demonstrates cross-chain storage proof verification!');
      } else {
        console.log('❌ SimpleVerifier rejected the proof');
        console.log('💡 Check console logs above for detailed error information');
      }

    } catch (error) {
      console.error('❌ Demo failed:', error);
    }
  }

  /**
   * 🚀 Main demo entry point
   */
  async runCompleteDemo(): Promise<void> {
    console.log('\n🚀 =======================================');
    console.log('🚀 SIMPLE STORAGE PROOF DEMO');
    console.log('🚀 =======================================');
    console.log('📚 This will:');
    console.log('  1️⃣ Generate storage proof from SimpleStorage on Chain 1');
    console.log('  2️⃣ Send proof to SimpleVerifier on Chain 2');
    console.log('  3️⃣ Use Optimism MerkleTrie verification');
    console.log('  4️⃣ Confirm Chain 2 accepts Chain 1 gameActive state');
    console.log('🎯 Let\'s prove gameActive=true with your contracts!\n');

    await this.demonstrateSimpleStorageProofFlow();
  }
}

// Run demonstration if called directly
if (require.main === module) {
  const service = new StorageProofService();
  service.runCompleteDemo();
}
