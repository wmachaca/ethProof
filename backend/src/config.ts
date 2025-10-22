import { defineChain } from 'viem';

/**
 * 🔧 SIMPLE CONFIGURATION FOR PROOF OF CONCEPT
 */

// Define our two Anvil chains
export const anvilChain1 = defineChain({
  id: 31337,
  name: 'Anvil Chain 1',
  network: 'anvil1',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545'],
    },
    public: {
      http: ['http://127.0.0.1:8545'],
    },
  },
});

export const anvilChain2 = defineChain({
  id: 31338,
  name: 'Anvil Chain 2', 
  network: 'anvil2',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8546'], // Different port!
    },
    public: {
      http: ['http://127.0.0.1:8546'],
    },
  },
});

// Contract addresses (deploy and update these)
export const STORAGE_CONTRACT_ADDRESSES = {
  31337: '0x5FbDB2315678afecb367f032d93F642f64180aa3', // Update after deployment
  31338: '0x5FbDB2315678afecb367f032d93F642f64180aa3', // Update after deployment
};

export const VERIFIER_CONTRACT_ADDRESSES = {
  31337: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512', // Update after deployment
  31338: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512', // Update after deployment
};

export const SUPPORTED_CHAINS = [anvilChain1, anvilChain2];
