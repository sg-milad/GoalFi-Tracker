import React, { useState } from 'react';
import { Toaster } from 'react-hot-toast';
import { useWeb3 } from './hooks/useWeb3';
import { Header } from './components/Header';
import { Dashboard } from './components/Dashboard';
import { TaskForm } from './components/TaskForm';
import { StakeForm } from './components/StakeForm';

function App() {
  const {
    account,
    network,
    contract,
    usdtContract,
    connectWallet,
    switchNetwork,
  } = useWeb3();

  const [refreshKey, setRefreshKey] = useState(0);

  const handleSuccess = () => {
    setRefreshKey(prev => prev + 1);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <Toaster position="top-right" />
      <Header
        account={account}
        network={network}
        onConnect={connectWallet}
        onSwitchNetwork={switchNetwork}
      />
      
      {account ? (
        <div className="container mx-auto px-4 py-8">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <div className="lg:col-span-2">
              <Dashboard
                key={refreshKey}
                contract={contract}
                account={account}
              />
            </div>
            <div className="space-y-8">
              <StakeForm
                contract={contract}
                usdtContract={usdtContract}
                account={account}
                onSuccess={handleSuccess}
              />
              <TaskForm
                contract={contract}
                onSuccess={handleSuccess}
              />
            </div>
          </div>
        </div>
      ) : (
        <div className="flex items-center justify-center h-[calc(100vh-80px)]">
          <div className="text-center">
            <h2 className="text-2xl font-bold text-gray-800 mb-4">
              Welcome to GoalKeeper
            </h2>
            <p className="text-gray-600 mb-8">
              Connect your wallet to start managing your tasks
            </p>
            <button
              onClick={connectWallet}
              className="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors"
            >
              Connect Wallet
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;