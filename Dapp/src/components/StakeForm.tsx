import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import toast from 'react-hot-toast';
import { Coins } from 'lucide-react';

interface StakeFormProps {
  contract: ethers.Contract | null;
  usdtContract: ethers.Contract | null;
  account: string;
  onSuccess: () => void;
}

export function StakeForm({ contract, usdtContract, account, onSuccess }: StakeFormProps) {
  const [amount, setAmount] = useState('');
  const [loading, setLoading] = useState(false);
  const [balance, setBalance] = useState('0');
  const [allowance, setAllowance] = useState('0');

  useEffect(() => {
    const loadBalances = async () => {
      if (!usdtContract || !account || !contract) return;

      try {
        console.log('Loading USDT balances...');
        const balance = await usdtContract.balanceOf(account);
        console.log('USDT balance:', balance);
        
        const allowance = await usdtContract.allowance(account, await contract.getAddress());
        console.log('USDT allowance:', allowance);
        
        setBalance(ethers.formatUnits(balance, 6));
        setAllowance(ethers.formatUnits(allowance, 6));
        
        console.log('Balances loaded:', {
          balance: ethers.formatUnits(balance, 6),
          allowance: ethers.formatUnits(allowance, 6),
        });
      } catch (error) {
        console.error('Error loading balances:', error);
        toast.error('Failed to load USDT balance');
      }
    };

    loadBalances();
  }, [usdtContract, account, contract]);

  const handleApprove = async () => {
    if (!usdtContract || !contract || !amount) return;

    try {
      setLoading(true);
      console.log('Approving USDT...');
      
      const amountToApprove = ethers.parseUnits(amount, 6);
      const contractAddress = await contract.getAddress();
      const tx = await usdtContract.approve(contractAddress, amountToApprove);
      await tx.wait();
      
      console.log('USDT approved successfully');
      toast.success('USDT approved successfully');
      
      // Refresh allowance
      const newAllowance = await usdtContract.allowance(account, contractAddress);
      setAllowance(ethers.formatUnits(newAllowance, 6));
    } catch (error) {
      console.error('Approval error:', error);
      toast.error('Failed to approve USDT');
    } finally {
      setLoading(false);
    }
  };

  const handleStake = async () => {
    if (!contract || !amount) return;

    try {
      setLoading(true);
      console.log('Staking USDT...');
      
      const amountToStake = ethers.parseUnits(amount, 6);
      const tx = await contract.stakeTokens(amountToStake);
      await tx.wait();
      
      console.log('USDT staked successfully');
      toast.success('USDT staked successfully');
      setAmount('');
      onSuccess();
    } catch (error) {
      console.error('Staking error:', error);
      toast.error('Failed to stake USDT');
    } finally {
      setLoading(false);
    }
  };

  const needsApproval = Number(amount) > Number(allowance);

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-semibold">Stake USDT</h2>
        <Coins className="w-6 h-6 text-blue-600" />
      </div>

      <div className="mb-4">
        <div className="flex justify-between items-center mb-2">
          <label className="block text-sm font-medium text-gray-700">
            Amount
          </label>
          <span className="text-sm text-gray-500">
            Balance: {parseFloat(balance).toFixed(2)} USDT
          </span>
        </div>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="Enter amount"
          className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          min="0"
          step="0.000001"
          disabled={loading}
        />
      </div>

      {needsApproval ? (
        <button
          onClick={handleApprove}
          disabled={loading || !amount}
          className={`w-full bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700 transition-colors ${
            loading ? 'opacity-50 cursor-not-allowed' : ''
          }`}
        >
          {loading ? 'Approving...' : 'Approve USDT'}
        </button>
      ) : (
        <button
          onClick={handleStake}
          disabled={loading || !amount}
          className={`w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 transition-colors ${
            loading ? 'opacity-50 cursor-not-allowed' : ''
          }`}
        >
          {loading ? 'Staking...' : 'Stake USDT'}
        </button>
      )}
    </div>
  );
}