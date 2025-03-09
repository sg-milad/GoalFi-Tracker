import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { format } from 'date-fns';
import { Task } from '../types/contract';
import { Clock, CheckCircle, XCircle, Coins } from 'lucide-react';

interface DashboardProps {
  contract: ethers.Contract | null;
  account: string;
}

export function Dashboard({ contract, account }: DashboardProps) {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [stakedBalance, setStakedBalance] = useState<string>('0');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadDashboard = async () => {
      if (!contract || !account) return;

      try {
        setLoading(true);
        const taskIds = await contract.getTaskIds(account);
        console.log('Task IDs loaded:', taskIds);

        const taskPromises = taskIds.map(async (id: bigint) => {
          const task = await contract.getTaskDetails(id);
          return {
            owner: task[0],
            deadline: task[1],
            isCompleted: task[2],
            isPenalized: task[3],
            description: task[4]
          };
        });

        const tasks = await Promise.all(taskPromises);
        console.log('Tasks loaded:', tasks);
        setTasks(tasks);

        const balance = await contract.getStakedBalance(account);
        setStakedBalance(ethers.formatUnits(balance, 6));
      } catch (error) {
        console.error('Failed to load dashboard:', error);
      } finally {
        setLoading(false);
      }
    };

    loadDashboard();
  }, [contract, account]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold">Staked Balance</h2>
            <Coins className="w-6 h-6 text-blue-600" />
          </div>
          <p className="text-3xl font-bold">{stakedBalance} USDT</p>
        </div>

        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold">Active Tasks</h2>
            <Clock className="w-6 h-6 text-yellow-600" />
          </div>
          <p className="text-3xl font-bold">
            {tasks.filter(t => !t.isCompleted && !t.isPenalized).length}
          </p>
        </div>

        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold">Completed Tasks</h2>
            <CheckCircle className="w-6 h-6 text-green-600" />
          </div>
          <p className="text-3xl font-bold">
            {tasks.filter(t => t.isCompleted).length}
          </p>
        </div>
      </div>

      <div className="mt-8">
        <h2 className="text-2xl font-bold mb-6">Recent Tasks</h2>
        <div className="bg-white rounded-lg shadow-md overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Description
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Deadline
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {tasks.map((task, index) => (
                  <tr key={index}>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{task.description}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">
                        {format(new Date(Number(task.deadline) * 1000), 'PPP')}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        task.isCompleted
                          ? 'bg-green-100 text-green-800'
                          : task.isPenalized
                          ? 'bg-red-100 text-red-800'
                          : 'bg-yellow-100 text-yellow-800'
                      }`}>
                        {task.isCompleted ? 'Completed' : task.isPenalized ? 'Penalized' : 'Active'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}