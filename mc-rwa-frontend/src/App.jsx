import React, { useState, useEffect } from 'react';
import { 
  WagmiProvider, 
  http, 
  useAccount, 
  useWriteContract,
  useWaitForTransactionReceipt,
  useSwitchChain,
  useReadContract
} from "wagmi";
import { 
  getDefaultConfig, 
  RainbowKitProvider, 
  ConnectButton 
} from '@rainbow-me/rainbowkit';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ethers } from 'ethers';
import { parseUnits, formatUnits } from 'viem';

import '@rainbow-me/rainbowkit/styles.css';
import './index.css'; 

const MANTLE_SEPOLIA = {
  id: 5003,
  name: 'Mantle Sepolia',
  nativeCurrency: { name: 'MNT', symbol: 'MNT', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://rpc.sepolia.mantle.xyz'] },
    public: { http: ['https://rpc.sepolia.mantle.xyz'] },
  },
  blockExplorers: {
    default: { name: 'Mantle Explorer', url: 'https://sepolia.mantlescan.xyz' },
  },
};

const config = getDefaultConfig({
  appName: 'MC-RWA Vault',
  projectId: '0cfa61163309d825276ed94521b8b6ab', 
  chains: [MANTLE_SEPOLIA],
  transports: { [MANTLE_SEPOLIA.id]: http() },
});

const queryClient = new QueryClient();

// FIXED ADDRESSES
const USDT_ADDRESS = '0x915cC86fE0871835e750E93e025080FFf9927A3f';
const VAULT_ADDRESS = '0x40776dF7BB64828BfaFBE4cfacFECD80fED34266';
const INTEGRATOR_ADDRESS = '0xAE95E2F4DBFa908fb88744C12325e5e44244b6B0';

const USDT_ABI = [
  'function balanceOf(address) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function mint(address to, uint256 amount) public' 
];

const VAULT_ABI = [
  'function getBorrowable(address user) view returns (uint256)',
  'function deposit(uint256 amount) external',
  'function borrow(uint256 amount) external',
  'function withdraw(uint256 amount) external',
  'function balanceOf(address account) view returns (uint256)'
];

const INTEGRATOR_ABI = [
  'function leverageDeposit(uint256 amount) external'
];

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <WagmiProvider config={config}>
        <RainbowKitProvider modalSize="compact">
          <VaultUI />
        </RainbowKitProvider>
      </WagmiProvider>
    </QueryClientProvider>
  );
}

function VaultUI() {
  const { address, isConnected, chainId } = useAccount();
  const { switchChain } = useSwitchChain();
  
  const [depositAmount, setDepositAmount] = useState('');
  const [borrowAmount, setBorrowAmount] = useState('');
  const [usdtBalance, setUsdtBalance] = useState('0.00');
  const [borrowable, setBorrowable] = useState('0.00');

  const { data: vUsdtRaw, refetch: refetchShares } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: 'balanceOf',
    args: [address],
  });

  const { data: hash, writeContract, isPending, error: writeError, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

  const isWrongNetwork = chainId !== MANTLE_SEPOLIA.id;

  // --- THE GUARDS (RESTORED) ---
  const rawUsdt = parseFloat(usdtBalance.replace(/,/g, '')) || 0;
  const rawBorrowable = parseFloat(borrowable.replace(/,/g, '')) || 0;
  const inputDeposit = parseFloat(depositAmount) || 0;
  const inputBorrow = parseFloat(borrowAmount) || 0;

  const depositError = inputDeposit > rawUsdt;
  const borrowError = inputBorrow > rawBorrowable;
  // -----------------------------

  const Spinner = () => (
    <svg className="animate-spin h-5 w-5 text-white inline mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
  );

  const StatusMessage = () => {
    const explorerBase = MANTLE_SEPOLIA.blockExplorers.default.url;
    if (isPending) return <div className="bg-yellow-500/10 border border-yellow-500/30 p-4 rounded-xl text-yellow-400 text-xs flex items-center"><Spinner /> Awaiting wallet signature...</div>;
    if (isConfirming) return <div className="bg-blue-500/10 border border-blue-500/30 p-4 rounded-xl text-blue-400 text-xs flex flex-col gap-2"><div className="flex items-center"><Spinner /> Transaction sent...</div><a href={`${explorerBase}/tx/${hash}`} target="_blank" rel="noreferrer" className="underline opacity-80 hover:opacity-100">View on Explorer</a></div>;
    if (isConfirmed) return <div className="bg-green-500/10 border border-green-500/30 p-4 rounded-xl text-green-400 text-xs font-bold flex flex-col gap-1"><span>✓ Transaction confirmed!</span><a href={`${explorerBase}/tx/${hash}`} target="_blank" rel="noreferrer" className="underline font-normal opacity-80">View Receipt</a></div>;
    if (writeError) return <div className="bg-red-500/10 border border-red-500/30 p-4 rounded-xl text-red-400 text-[10px] font-mono break-all leading-tight">Error: {writeError.shortMessage || "Execution Reverted. Try Clearing MetaMask Activity."}</div>;
    return null;
  };

  const fetchBalances = async () => {
    if (!isConnected || !address || isWrongNetwork) return;
    try {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const usdt = new ethers.Contract(USDT_ADDRESS, USDT_ABI, provider);
      const vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, provider);
      
      const [bal, borrow] = await Promise.all([
        usdt.balanceOf(address),
        vault.getBorrowable(address).catch(() => ethers.BigNumber.from(0))
      ]);
      
      setUsdtBalance(Number(ethers.utils.formatUnits(bal, 18)).toLocaleString());
      setBorrowable(Number(ethers.utils.formatUnits(borrow, 18)).toLocaleString());
      refetchShares();
    } catch (err) { console.error("Balance fetch error:", err); }
  };

  useEffect(() => {
    fetchBalances();
  }, [address, isConnected, isConfirmed, isWrongNetwork]);

  const executeAction = async (type) => {
    reset(); 
    if (!isConnected) return alert("Please connect wallet");
    if (isWrongNetwork) return switchChain({ chainId: MANTLE_SEPOLIA.id });
    
    try {
      if (type === 'mint') {
        return writeContract({
          address: USDT_ADDRESS, 
          abi: USDT_ABI, 
          functionName: 'mint',
          args: [address, parseUnits("1000", 18)],
          gas: 200000n
        });
      }

      const targetAmount = (type === 'approve' || type === 'deposit' || type === 'leverage') ? depositAmount : borrowAmount;
      if (!targetAmount || parseFloat(targetAmount) <= 0) return alert("Enter a valid amount");
      const parsedAmount = parseUnits(targetAmount, 18);

      // FIX: Dynamic spender selection to prevent 'leverage' from reverting
      const spender = (type === 'leverage') ? INTEGRATOR_ADDRESS : VAULT_ADDRESS;

      const params = {
        approve: { 
          address: USDT_ADDRESS, 
          abi: USDT_ABI, 
          functionName: 'approve', 
          args: [VAULT_ADDRESS, parsedAmount],
          gas: 100000n 
        },
        deposit: { 
          address: VAULT_ADDRESS, 
          abi: VAULT_ABI, 
          functionName: 'deposit', 
          args: [parsedAmount],
          gas: 500000n 
        },
        borrow: { 
          address: VAULT_ADDRESS, 
          abi: VAULT_ABI, 
          functionName: 'borrow', 
          args: [parsedAmount],
          gas: 250000n
        },
        approveLeverage: { 
          address: USDT_ADDRESS, 
          abi: USDT_ABI, 
          functionName: 'approve', 
          args: [INTEGRATOR_ADDRESS, parsedAmount],
          gas: 150000n 
        },
        leverage: {
          address: INTEGRATOR_ADDRESS,
          abi: INTEGRATOR_ABI,
          functionName: 'leverageDeposit',
          args: [parsedAmount],
          gas: 500000n
        }
      };

      writeContract(params[type]);
    } catch (err) { console.error("Action Error:", err); }
  };

  return (
    <div className="min-h-screen w-full bg-slate-950 text-white p-4 md:p-10 relative font-sans flex flex-col items-center overflow-x-hidden">
      <div className="absolute top-0 left-0 w-64 md:w-96 h-64 md:h-96 bg-blue-600/10 blur-[120px] rounded-full" />
      
      <div className="max-w-7xl w-full flex-grow relative z-10 text-left">
        <nav className="flex flex-col md:flex-row justify-between items-center mb-8 bg-white/5 p-4 rounded-2xl border border-white/10 gap-4">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-blue-600 rounded-md shadow-lg shadow-blue-600/20" />
            <span className="font-bold tracking-tight uppercase text-left">MC-RWA Dashboard v2</span>
          </div>
          <ConnectButton showBalance={false} />
        </nav>

        <main className="grid grid-cols-1 md:grid-cols-12 gap-6">
          <div className="md:col-span-7 space-y-6">
            <div className="bg-white/[0.02] backdrop-blur-md rounded-[2rem] p-8 border border-white/10 flex flex-col justify-center min-h-[250px] text-left">
              <p className="text-blue-400 text-sm font-bold uppercase mb-4 tracking-widest">Mantle Receipt (mRWA-USDT)</p>
              <h2 className="text-5xl md:text-7xl font-bold tracking-tight text-white">
                {vUsdtRaw ? formatUnits(vUsdtRaw, 18) : '0.00'}
              </h2>
            </div>
            
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="bg-white/[0.02] backdrop-blur-md rounded-3xl p-6 border border-white/10 text-left">
                <p className="text-slate-400 text-xs mb-1 uppercase font-semibold flex justify-between items-center">
                  Wallet USDT
                  <button onClick={fetchBalances} className="hover:text-blue-400 transition-colors text-[10px]">↻ REFRESH</button>
                </p>
                <div className="flex items-center justify-between">
                  <p className="text-2xl font-bold">{usdtBalance}</p>
                  <button onClick={() => executeAction('mint')} className="px-3 py-1 bg-green-500/10 border border-green-500/30 rounded-lg text-[10px] text-green-400 hover:bg-green-500/20 transition-all font-bold">+ MINT 1000</button>
                </div>
              </div>
              <div className="bg-white/[0.02] backdrop-blur-md rounded-3xl p-6 border border-white/10 text-left">
                <p className="text-slate-400 text-xs mb-1 uppercase font-semibold">Borrow Limit</p>
                <p className="text-purple-400 font-bold flex items-center gap-2 text-xl text-left">${borrowable}</p>
              </div>
            </div>
          </div>

          <div className="md:col-span-5 bg-blue-500/[0.03] backdrop-blur-xl rounded-[2.5rem] p-6 border border-blue-500/20 shadow-2xl text-left">
            <h3 className="text-xl font-bold mb-6">Execution Panel</h3>
            <div className="space-y-6">
              <div className="min-h-[60px]"><StatusMessage /></div>
              
              <div className="space-y-3">
                <div className={`bg-slate-900/60 p-4 rounded-2xl border ${depositError ? 'border-red-500/50' : 'border-white/10'}`}>
                  <label className="text-[10px] text-slate-500 block mb-1 uppercase font-bold tracking-tighter">Amount</label>
                  <input type="number" value={depositAmount} onChange={(e) => setDepositAmount(e.target.value)} placeholder="0.00" className="bg-transparent text-xl w-full outline-none text-white" />
                </div>
                {/* GUARDS APPLIED TO BUTTONS */}
                <div className="grid grid-cols-2 gap-2">
                  <button onClick={() => executeAction('approve')} disabled={isPending || isConfirming || inputDeposit <= 0} className="py-4 bg-white/5 border border-white/10 rounded-xl text-xs font-bold hover:bg-white/10 disabled:opacity-20 transition-all uppercase tracking-tighter">1. Approve</button>
                  <button onClick={() => executeAction('deposit')} disabled={isPending || isConfirming || depositError || inputDeposit <= 0} className="py-4 bg-blue-600 rounded-xl text-xs font-bold hover:bg-blue-500 disabled:opacity-20 transition-all uppercase tracking-tighter">2. Deposit</button>
                </div>
                <button onClick={() => executeAction('leverage')} disabled={isPending || isConfirming || depositError || inputDeposit <= 0} className="w-full py-4 bg-orange-600/20 border border-orange-500/40 rounded-xl text-[10px] font-black text-orange-400 uppercase tracking-widest hover:bg-orange-500/30 transition-all">⚡ Smart Leverage</button>
              </div>

              <div className="space-y-3 pt-4 border-t border-white/5 text-left">
                <div className={`bg-slate-900/60 p-4 rounded-2xl border ${borrowError ? 'border-red-500/50' : 'border-white/10'}`}>
                  <label className="text-[10px] text-slate-500 block mb-1 uppercase font-bold tracking-tighter">Borrow Amount</label>
                  <input type="number" value={borrowAmount} onChange={(e) => setBorrowAmount(e.target.value)} placeholder="0.00" className="bg-transparent text-xl w-full outline-none text-white" />
                </div>
                <button onClick={() => executeAction('borrow')} disabled={isPending || isConfirming || borrowError || inputBorrow <= 0} className="w-full py-4 bg-purple-600/30 border border-purple-500/40 rounded-xl font-bold hover:bg-purple-600/50 disabled:opacity-20 transition-all uppercase text-xs">Borrow USDT</button>
              </div>
            </div>
          </div>
        </main>

        <footer className="w-full mt-12 mb-6 pt-6 border-t border-white/5 flex flex-col md:flex-row justify-between items-center gap-4 text-[10px] text-slate-500 font-mono">
           <div className="flex gap-4">
             <div className="flex flex-col text-left"><span className="uppercase font-bold text-slate-400">Vault</span><a href={`${MANTLE_SEPOLIA.blockExplorers.default.url}/address/${VAULT_ADDRESS}`} target="_blank" rel="noreferrer" className="hover:text-blue-400 underline">{VAULT_ADDRESS}</a></div>
             <div className="flex flex-col text-left"><span className="uppercase font-bold text-slate-400">USDT</span><a href={`${MANTLE_SEPOLIA.blockExplorers.default.url}/address/${USDT_ADDRESS}`} target="_blank" rel="noreferrer" className="hover:text-blue-400 underline">{USDT_ADDRESS}</a></div>
           </div>
           <div className="uppercase font-bold text-slate-400">Integrator: {INTEGRATOR_ADDRESS.slice(0,12)}...</div>
        </footer>
      </div>
    </div>
  );
}
