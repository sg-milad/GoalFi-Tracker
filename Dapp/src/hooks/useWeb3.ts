import { useState, useEffect, useCallback } from 'react';
import { ethers } from 'ethers';
import toast from 'react-hot-toast';
import { CONTRACT_ABI, USDT_ABI } from '../types/contract';

const NETWORKS = {
  sepolia: {
    chainId: '0xaa36a7',
    name: 'Sepolia',
    contractAddress: '0x1234567890123456789012345678901234567890', // Replace with actual address
    usdtAddress: '0x1234567890123456789012345678901234567890', // Replace with actual address
    rpcUrl: 'https://sepolia.infura.io/v3/your-project-id', // Replace with your Infura project ID
  },
  localhost: {
    chainId: '0x7a69',
    name: 'Localhost',
    contractAddress: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512', // Replace with actual address
    usdtAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3', // Replace with actual address
    rpcUrl: 'http://localhost:8545',
  },
};

export function useWeb3() {
  const [provider, setProvider] = useState<ethers.BrowserProvider | null>(null);
  const [signer, setSigner] = useState<ethers.JsonRpcSigner | null>(null);
  const [account, setAccount] = useState<string>('');
  const [network, setNetwork] = useState<string>('');
  const [contract, setContract] = useState<ethers.Contract | null>(null);
  const [usdtContract, setUsdtContract] = useState<ethers.Contract | null>(null);
  const [error, setError] = useState<string>('');

  const connectWallet = useCallback(async () => {
    try {
      console.log('Connecting wallet...');
      if (!window.ethereum) {
        throw new Error('Please install MetaMask');
      }

      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const account = await signer.getAddress();
      const network = await provider.getNetwork();
      const chainId = '0x' + network.chainId.toString(16);

      console.log('Connected to network:', chainId);

      const networkConfig = Object.values(NETWORKS).find(n => n.chainId === chainId);
      if (!networkConfig) {
        throw new Error('Unsupported network');
      }

      const contract = new ethers.Contract(
        networkConfig.contractAddress,
        CONTRACT_ABI,
        signer
      );

      const usdtContract = new ethers.Contract(
        networkConfig.usdtAddress,
        USDT_ABI,
        signer
      );

      setProvider(provider);
      setSigner(signer);
      setAccount(account);
      setNetwork(networkConfig.name.toLowerCase());
      setContract(contract);
      setUsdtContract(usdtContract);
      setError('');

      console.log('Wallet connected successfully:', {
        account,
        network: networkConfig.name,
        chainId,
      });
    } catch (err) {
      console.error('Wallet connection error:', err);
      setError(err instanceof Error ? err.message : 'Failed to connect wallet');
      toast.error(err instanceof Error ? err.message : 'Failed to connect wallet');
    }
  }, []);

  const switchNetwork = async (networkName: 'sepolia' | 'localhost') => {
    try {
      console.log('Switching to network:', networkName);
      const network = NETWORKS[networkName];

      try {
        await window.ethereum.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: network.chainId }],
        });
      } catch (switchError: any) {
        // This error code indicates that the chain has not been added to MetaMask
        if (switchError.code === 4902) {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [
              {
                chainId: network.chainId,
                chainName: network.name,
                rpcUrls: [network.rpcUrl],
              },
            ],
          });
        } else {
          throw switchError;
        }
      }

      await connectWallet();
      console.log('Network switched successfully to:', networkName);
    } catch (err) {
      console.error('Network switch error:', err);
      setError(err instanceof Error ? err.message : 'Failed to switch network');
      toast.error(err instanceof Error ? err.message : 'Failed to switch network');
    }
  };

  useEffect(() => {
    if (window.ethereum) {
      window.ethereum.on('accountsChanged', connectWallet);
      window.ethereum.on('chainChanged', connectWallet);
      return () => {
        window.ethereum.removeListener('accountsChanged', connectWallet);
        window.ethereum.removeListener('chainChanged', connectWallet);
      };
    }
  }, [connectWallet]);

  return {
    provider,
    signer,
    account,
    network,
    contract,
    usdtContract,
    error,
    connectWallet,
    switchNetwork,
  };
}