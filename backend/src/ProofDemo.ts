import { StorageProofService } from './StorageProofService';

/**
 * 🎯 MAIN PROOF OF CONCEPT DEMO
 * 
 * This demonstrates the complete flow:
 * 1. State changes on Chain 1 (storage updates)
 * 2. Generate storage proof using eth_getProof  
 * 3. Verify proof on Chain 2
 * 4. Show cross-chain state verification
 */

async function main() {
  console.log('\n🚀 =======================================');
  console.log('🚀 STORAGE PROOF DEMO - STARTING');
  console.log('🚀 =======================================');

  try {
    // Initialize the storage proof service
    const proofService = new StorageProofService();

    // Run the demonstration
    await proofService.demonstrateStorageProofFlow();

    console.log('\n✅ Demo completed successfully!');
    console.log('🔥 Next steps:');
    console.log('  1. Deploy contracts to both Anvil chains');
    console.log('  2. Update contract addresses in config.ts');
    console.log('  3. Run: npm start');
    console.log('  4. Test state changes and proof verification');

  } catch (error) {
    console.error('\n❌ Demo failed:', error);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Demo interrupted by user');
  process.exit(0);
});

// Run the demo
main();
