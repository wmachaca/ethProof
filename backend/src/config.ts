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

// Contract addresses (updated by deploy script)
export const STORAGE_CONTRACT_ADDRESSES: Record<number, string> = {
  31337: '0x5FbDB2315678afecb367f032d93F642f64180aa3', // SimpleStorage on Chain 1
  31338: '0x0000000000000000000000000000000000000000', // Not deployed on Chain 2
};

export const VERIFIER_CONTRACT_ADDRESSES: Record<number, string> = {
  31337: '0x0000000000000000000000000000000000000000', // Not deployed on Chain 1
  31338: '0x5FbDB2315678afecb367f032d93F642f64180aa3', // SimpleVerifier on Chain 2
};

export const SUPPORTED_CHAINS = [anvilChain1, anvilChain2];
