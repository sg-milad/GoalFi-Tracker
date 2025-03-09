import React from 'react';
import { Wallet, Network } from 'lucide-react';

interface HeaderProps {
  account: string;
  network: string;
  onConnect: () => void;
  onSwitchNetwork: (network: 'sepolia' | 'localhost') => void;
}

export function Header({ account, network, onConnect, onSwitchNetwork }: HeaderProps) {
  return (
    <header className="bg-white shadow-md">
      <div className="container mx-auto px-4 py-4 flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <h1 className="text-2xl font-bold text-gray-800">GoalKeeper</h1>
          <span className="text-sm text-gray-500">DApp</span>
        </div>

        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-2">
            <Network className="w-5 h-5 text-gray-600" />
            <select
              className="bg-gray-100 rounded-md px-3 py-1 text-sm"
              value={network}
              onChange={(e) => onSwitchNetwork(e.target.value as 'sepolia' | 'localhost')}
            >
              <option value="sepolia">Sepolia</option>
              <option value="localhost">Localhost</option>
            </select>
          </div>

          {account ? (
            <div className="flex items-center space-x-2 bg-gray-100 rounded-full px-4 py-2">
              <Wallet className="w-5 h-5 text-gray-600" />
              <span className="text-sm">
                {account.slice(0, 6)}...{account.slice(-4)}
              </span>
            </div>
          ) : (
            <button
              onClick={onConnect}
              className="flex items-center space-x-2 bg-blue-600 text-white rounded-full px-4 py-2 hover:bg-blue-700 transition-colors"
            >
              <Wallet className="w-5 h-5" />
              <span>Connect Wallet</span>
            </button>
          )}
        </div>
      </div>
    </header>
  );
}