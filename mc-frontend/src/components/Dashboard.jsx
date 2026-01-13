import React, { useState, useEffect } from 'react';
import {
    useAccount,
    useWriteContract,
    useWaitForTransactionReceipt,
    useSwitchChain,
    useReadContract
} from "wagmi";
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { ethers } from 'ethers';
import { parseUnits, formatUnits } from 'viem';
import { Link } from 'react-router-dom';

import {
    MANTLE_SEPOLIA,
    USDT_ADDRESS,
    VAULT_ADDRESS,
    INTEGRATOR_ADDRESS,
    USDT_ABI,
    VAULT_ABI,
    INTEGRATOR_ABI
} from '../constants';

export default function Dashboard() {
    const { address, isConnected, chainId } = useAccount();
    const { switchChain } = useSwitchChain();

    const [depositAmount, setDepositAmount] = useState('');
    const [borrowAmount, setBorrowAmount] = useState('');
    const [withdrawAmount, setWithdrawAmount] = useState('');
    const [repayAmount, setRepayAmount] = useState('');
    const [repayToken, setRepayToken] = useState('usdt'); 
    const [usdtBalance, setUsdtBalance] = useState('0.00');
    const [borrowable, setBorrowable] = useState('0.00');
    const [activeTab, setActiveTab] = useState('deposit'); 
    const [healthData, setHealthData] = useState({ healthFactor: '0', collateral: '0', debt: '0', ltv: '0' });
    const [vaultApproved, setVaultApproved] = useState(false);
    const [integratorApproved, setIntegratorApproved] = useState(false);
    const [protocolStats, setProtocolStats] = useState({ tvl: '0', totalDebt: '0', utilization: '0', avgHealthFactor: '0' });
    const [oracleStatus, setOracleStatus] = useState({ isConnected: false, aggregators: [], fallbackPrice: '1.00' });
    const [allowedBorrowTokens, setAllowedBorrowTokens] = useState([]);

    const { data: vUsdtRaw, refetch: refetchShares } = useReadContract({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: 'balanceOf',
        args: [address],
    });

    const { data: healthFactorRaw } = useReadContract({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: 'getHealthFactor',
        args: [address],
    });

    const { data: collateralRaw } = useReadContract({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: 'getTotalCollateralUSD',
        args: [address],
    });

    const { data: debtRaw } = useReadContract({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: 'getDebtUSDT',
        args: [address],
    });

    const { data: isLiquidatableRaw } = useReadContract({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: 'isLiquidatable',
        args: [address],
    });

    const { data: hash, writeContract, isPending, error: writeError, reset } = useWriteContract();
    const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

    const isWrongNetwork = chainId !== MANTLE_SEPOLIA.id;
    const rawUsdt = parseFloat(usdtBalance.replace(/,/g, '')) || 0;
    const rawBorrowable = parseFloat(borrowable.replace(/,/g, '')) || 0;
    const inputDeposit = parseFloat(depositAmount) || 0;
    const inputBorrow = parseFloat(borrowAmount) || 0;
    const inputWithdraw = parseFloat(withdrawAmount) || 0;
    const inputRepay = parseFloat(repayAmount) || 0;

    const depositError = inputDeposit > rawUsdt;
    const depositApprovalError = inputDeposit > 0 && !vaultApproved;
    const borrowError = inputBorrow > rawBorrowable;
    const withdrawError = inputWithdraw > rawBorrowable;
    const repayError = inputRepay > rawUsdt;
    const leverageApprovalError = inputDeposit > 0 && !integratorApproved;
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
        if (writeError) {
            const errorMsg = writeError.message || writeError.shortMessage || "Execution Reverted";
            const details = writeError.details || writeError.cause?.message || "";
            return (
                <div className="bg-red-500/10 border border-red-500/30 p-4 rounded-xl text-red-400 text-xs font-mono break-all leading-tight">
                    <div>Error: {errorMsg}</div>
                    {details && <div className="text-red-300 mt-2">{details}</div>}
                    <div className="text-red-300 mt-2 text-xs">Check browser console (F12) for DebugLog events</div>
                </div>
            );
        }
        return null;
    };

    const fetchBalances = async () => {
        if (!isConnected || !address || isWrongNetwork) return;
        try {
            const provider = new ethers.providers.Web3Provider(window.ethereum);
            const usdt = new ethers.Contract(USDT_ADDRESS, USDT_ABI, provider);
            const vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, provider);

            const bal = await usdt.balanceOf(address);
            const vaultBalance = await vault.balanceOf(address).catch(() => ethers.BigNumber.from(0));
            const collateral = await vault.getTotalCollateralUSD(address).catch(() => ethers.BigNumber.from(0));
            const debt = await vault.getDebtUSDT(address).catch(() => ethers.BigNumber.from(0));
            const hf = await vault.getHealthFactor(address).catch(() => ethers.BigNumber.from(0));
            const vaultAllowance = await usdt.allowance(address, VAULT_ADDRESS).catch(() => ethers.BigNumber.from(0));
            const integratorAllowance = await usdt.allowance(address, INTEGRATOR_ADDRESS).catch(() => ethers.BigNumber.from(0));
            setVaultApproved(vaultAllowance.gt(0));
            setIntegratorApproved(integratorAllowance.gt(0));

            const collateralNum = parseFloat(ethers.utils.formatUnits(collateral, 18));
            const debtNum = parseFloat(ethers.utils.formatUnits(debt, 18));
            const hfNum = parseFloat(ethers.utils.formatUnits(hf, 18));
            const ltv = debtNum > 0 && collateralNum > 0 ? ((debtNum / collateralNum) * 100).toFixed(2) : '0.00';

            setUsdtBalance(Number(ethers.utils.formatUnits(bal, 18)).toLocaleString());
            setBorrowable(Number(ethers.utils.formatUnits(vaultBalance.mul(50).div(100), 18)).toLocaleString());
            setHealthData({
                healthFactor: hfNum > 0 ? hfNum.toFixed(2) : '0.00',
                collateral: collateralNum.toLocaleString('en-US', { maximumFractionDigits: 2 }),
                debt: debtNum.toLocaleString('en-US', { maximumFractionDigits: 2 }),
                ltv: ltv,
                isLiquidatable: hfNum > 0 && hfNum < 1
            });
            refetchShares();
        } catch (err) {
            console.error("Balance fetch error:", err);
        }
    };

    const fetchProtocolStats = async () => {
        if (!isConnected || isWrongNetwork) return;
        try {
            const provider = new ethers.providers.Web3Provider(window.ethereum);
            const vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, provider);
            const userCollateral = await vault.getUserCollateralValue(address).catch(() => ethers.BigNumber.from(0));
            const userDebt = await vault.getVaultDebt(address).catch(() => ethers.BigNumber.from(0));
            const interestRate = await vault.interestRatePerYear().catch(() => ethers.BigNumber.from(500));

            const tvlNum = parseFloat(ethers.utils.formatUnits(userCollateral, 18));
            const debtNum = parseFloat(ethers.utils.formatUnits(userDebt, 18));
            const rateNum = parseInt(interestRate.toString()) / 100;
            const utilizationNum = tvlNum > 0 ? ((debtNum / tvlNum) * 100) : 0;

            setProtocolStats({
                tvl: tvlNum.toLocaleString('en-US', { maximumFractionDigits: 0 }),
                totalDebt: debtNum.toLocaleString('en-US', { maximumFractionDigits: 0 }),
                utilization: utilizationNum.toFixed(1),
                avgHealthFactor: ((tvlNum * 50) / 100 / (debtNum || 1)).toFixed(2),
                interestRate: rateNum.toFixed(2)
            });
        } catch (err) {
            console.error("Protocol stats fetch error:", err);
        }
    };

    const fetchOracleStatus = async () => {
        if (!isConnected || isWrongNetwork) return;
        try {
            const provider = new ethers.providers.Web3Provider(window.ethereum);
            const vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, provider);
            const oracleAddr = await vault.oracle?.().catch(() => null);
            
            if (oracleAddr) {
                setOracleStatus({
                    isConnected: true,
                    aggregators: ['Chainlink Feed'],
                    fallbackPrice: '1.00'
                });
            } else {
                setOracleStatus({
                    isConnected: false,
                    aggregators: [],
                    fallbackPrice: 'Not Set'
                });
            }

            const allowedTokens = await vault.allowedBorrowTokens?.().catch(() => []);
            setAllowedBorrowTokens(allowedTokens || [USDT_ADDRESS]);
        } catch (err) {
            console.error("Oracle status fetch error:", err);
        }
    };

    useEffect(() => {
        fetchBalances();
        fetchProtocolStats();
        fetchOracleStatus();
    }, [address, isConnected, isConfirmed, isWrongNetwork]);
    useEffect(() => {
        if (isConfirmed) {
            setTimeout(() => {
                fetchBalances();
                fetchProtocolStats();
            }, 1000);
        }
    }, [isConfirmed]);
    useEffect(() => {
        if (!address || !isConnected) {
            setHealthData({
                healthFactor: '0.00',
                collateral: '0',
                debt: '0',
                ltv: '0.00',
                isLiquidatable: false
            });
            return;
        }

        try {
            // Convert raw BigNumber data from contracts to formatted numbers
            const hfNum = healthFactorRaw ? parseFloat(formatUnits(BigInt(healthFactorRaw.toString()), 18)) : 0;
            const collateralNum = collateralRaw ? parseFloat(formatUnits(BigInt(collateralRaw.toString()), 18)) : 0;
            const debtNum = debtRaw ? parseFloat(formatUnits(BigInt(debtRaw.toString()), 18)) : 0;

            // Calculate LTV: (debt / collateral) * 100
            const ltv = debtNum > 0 && collateralNum > 0
                ? ((debtNum / collateralNum) * 100).toFixed(2)
                : '0.00';

            // Format numbers with commas for display
            const formattedCollateral = collateralNum.toLocaleString('en-US', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            });

            const formattedDebt = debtNum.toLocaleString('en-US', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            });

            setHealthData({
                healthFactor: hfNum > 0 ? hfNum.toFixed(2) : '0.00',
                collateral: formattedCollateral,
                debt: formattedDebt,
                ltv: ltv,
                isLiquidatable: isLiquidatableRaw || false
            });
        } catch (err) {
            console.error("Error updating health data:", err);
        }
    }, [healthFactorRaw, collateralRaw, debtRaw, isLiquidatableRaw, address, isConnected]);

    const executeAction = async (type) => {
        reset();
        if (!isConnected) return alert("Please connect wallet");
        if (isWrongNetwork) return switchChain({ chainId: MANTLE_SEPOLIA.id });

        try {
            if (type === 'mint') {
                alert('To mint USDT, run this command in terminal:\ncast send ' + USDT_ADDRESS + ' "mint(address,uint256)" ' + address + ' 1000000000000000000000 --rpc-url https://rpc.sepolia.mantle.xyz --private-key YOUR_PRIVATE_KEY');
                return;
            }

            let targetAmount;
            if (type === 'approve' || type === 'deposit' || type === 'approveLeverage' || type === 'leverage') {
                targetAmount = depositAmount;
            } else if (type === 'borrow') {
                targetAmount = borrowAmount;
            } else if (type === 'withdraw') {
                targetAmount = withdrawAmount;
            } else if (type === 'repay') {
                targetAmount = repayAmount;
            }

            if (!targetAmount || parseFloat(targetAmount) <= 0) return alert("Enter a valid amount");
            const parsedAmount = parseUnits(targetAmount, 18);

            // Pre-deposit validation
            if (type === 'deposit') {
                if (!vaultApproved) {
                    return alert('⚠️ USDT approval required!\n\nBefore you can deposit, you must approve the Vault to spend your USDT.\n\n1. Click "Approve" button first\n2. Sign the approval transaction\n3. Once approved (button shows ✓), click "Deposit"');
                }
            }

            // Pre-borrow validation
            if (type === 'borrow') {
                const collateralNum = parseFloat(healthData.collateral.replace(/,/g, '')) || 0;
                const debtNum = parseFloat(healthData.debt.replace(/,/g, '')) || 0;
                const borrowNum = parseFloat(targetAmount) || 0;

                if (collateralNum === 0) {
                    return alert('⚠️ No collateral deposited!\n\nYou must deposit USDT as collateral before borrowing.\n\n1. Go to Deposit tab\n2. Deposit USDT amount\n3. Then return to Borrow tab');
                }

                const maxBorrow = (collateralNum * 50) / 100; // 50% LTV
                const wouldDebt = debtNum + borrowNum;

                if (wouldDebt > maxBorrow) {
                    return alert(`⚠️ Borrow amount exceeds your limit!\n\nCollateral: $${collateralNum.toFixed(2)}\nCurrent Debt: $${debtNum.toFixed(2)}\nMax Total Debt: $${maxBorrow.toFixed(2)}\nRequested: $${borrowNum.toFixed(2)}\n\nAvailable to borrow: $${(maxBorrow - debtNum).toFixed(2)}`);
                }
            }

            // Pre-leverage validation
            if (type === 'leverage') {
                if (!integratorApproved) {
                    return alert('⚠️ Leverage approval required!\n\nBefore you can use auto-leverage, you must approve the Integrator contract.\n\n1. Click "Approve & Leverage" button\n2. This will both approve and execute the leverage in one transaction');
                }
            }

            const params = {
                approve: {
                    address: USDT_ADDRESS,
                    abi: USDT_ABI,
                    functionName: 'approve',
                    args: [VAULT_ADDRESS, parsedAmount],
                },
                deposit: {
                    address: VAULT_ADDRESS,
                    abi: VAULT_ABI,
                    functionName: 'depositERC20',
                    args: [USDT_ADDRESS, parsedAmount],
                },
                borrow: {
                    address: VAULT_ADDRESS,
                    abi: VAULT_ABI,
                    functionName: 'borrow',
                    args: [USDT_ADDRESS, parsedAmount], // Assume borrowing USDT standard
                },
                withdraw: {
                    address: VAULT_ADDRESS,
                    abi: VAULT_ABI,
                    functionName: 'withdrawERC20',
                    args: [USDT_ADDRESS, parsedAmount],
                },
                repay: {
                    address: VAULT_ADDRESS,
                    abi: VAULT_ABI,
                    functionName: repayToken === 'usdt' ? 'repay' : 'repayWithBorrowToken',
                    args: repayToken === 'usdt' 
                        ? [parsedAmount]
                        : [repayToken, parsedAmount],
                },
                approveLeverage: {
                    address: USDT_ADDRESS,
                    abi: USDT_ABI,
                    functionName: 'approve',
                    args: [INTEGRATOR_ADDRESS, parsedAmount],
                },
                leverage: {
                    address: INTEGRATOR_ADDRESS,
                    abi: INTEGRATOR_ABI,
                    functionName: 'automatedLeverage',
                    args: [USDT_ADDRESS, parsedAmount],
                }
            };

            if (!params[type]) {
                console.error(`Unknown action type: ${type}`);
                return alert(`Unknown action: ${type}`);
            }

            writeContract(params[type]);
        } catch (err) {
            console.error("Action Error:", err);
            alert(`Error: ${err.message || 'Transaction failed'}`);
        }
    };

    return (
        <div className="min-h-screen w-full bg-gradient-to-br from-slate-950 via-blue-950 to-slate-950 text-white p-4 md:p-10 relative font-sans flex flex-col items-center overflow-x-hidden">
            <div className="absolute top-0 left-0 w-64 md:w-96 h-64 md:h-96 bg-blue-600/10 blur-[120px] rounded-full" />
            <div className="absolute bottom-0 right-0 w-96 h-96 bg-purple-600/10 blur-[120px] rounded-full" />

            <div className="max-w-7xl w-full flex-grow relative z-10 text-left">
                <nav className="flex flex-col md:flex-row justify-between items-center mb-8 bg-white/5 p-4 rounded-2xl border border-white/10 gap-4 backdrop-blur-sm">
                    <div className="flex items-center gap-3">
                        <div className="w-8 h-8 bg-gradient-to-br from-blue-600 to-purple-600 rounded-lg shadow-lg shadow-blue-600/30" />
                        <div>
                            <span className="font-black tracking-tight uppercase text-lg block">MC-RWA Vault</span>
                            <span className="text-[10px] text-slate-400">DeFi Lending Protocol</span>
                        </div>
                    </div>
                    <div className="flex items-center gap-4">
                        <Link to="/tutorial" className="text-sm font-bold text-slate-300 hover:text-white transition-colors bg-white/5 px-4 py-2 rounded-lg">🎓 Start Tutorial</Link>
                        <ConnectButton showBalance={false} />
                    </div>
                </nav>

                {/* HEALTH INDICATORS ROW */}
                <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
                    <div className="bg-white/[0.03] backdrop-blur-md rounded-2xl p-4 border border-white/10 text-center">
                        <p className="text-xs text-slate-400 uppercase font-bold mb-2">Health Factor</p>
                        <div className={`text-4xl font-black ${parseFloat(healthData.healthFactor) > 2 ? 'text-green-400' :
                                parseFloat(healthData.healthFactor) > 1 ? 'text-yellow-400' :
                                    'text-red-400'
                            }`}>
                            {healthData.healthFactor}
                        </div>
                        <p className="text-xs text-slate-500 mt-2">
                            {parseFloat(healthData.healthFactor) > 2 ? '✓ Safe' :
                                parseFloat(healthData.healthFactor) > 1 ? '⚠ At Risk' :
                                    '✗ Liquidatable'}
                        </p>
                    </div>

                    <div className="bg-white/[0.03] backdrop-blur-md rounded-2xl p-4 border border-white/10 text-center">
                        <p className="text-xs text-slate-400 uppercase font-bold mb-2">LTV Ratio</p>
                        <div className="text-4xl font-black text-blue-400">{healthData.ltv}%</div>
                        <p className="text-xs text-slate-500 mt-2">Liquidation: 80%</p>
                    </div>

                    <div className="bg-white/[0.03] backdrop-blur-md rounded-2xl p-4 border border-white/10 text-center">
                        <p className="text-xs text-slate-400 uppercase font-bold mb-2">Collateral</p>
                        <div className="text-4xl font-black text-purple-400">${healthData.collateral}</div>
                        <p className="text-xs text-slate-500 mt-2">USD Value</p>
                    </div>

                    <div className="bg-white/[0.03] backdrop-blur-md rounded-2xl p-4 border border-white/10 text-center">
                        <p className="text-xs text-slate-400 uppercase font-bold mb-2">Total Debt</p>
                        <div className="text-4xl font-black text-red-400">${healthData.debt}</div>
                        <p className="text-xs text-slate-500 mt-2">USDT Borrowed</p>
                    </div>
                </div>

                {/* PROTOCOL ANALYTICS */}
                <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
                    <div className="bg-gradient-to-br from-blue-500/10 to-transparent backdrop-blur-md rounded-2xl p-4 border border-blue-500/20 text-left">
                        <p className="text-xs text-blue-400 uppercase font-bold mb-2">Total Value Locked</p>
                        <div className="text-3xl font-black text-blue-300">${protocolStats.tvl}</div>
                        <p className="text-xs text-slate-500 mt-2">Collateral in vault</p>
                    </div>

                    <div className="bg-gradient-to-br from-red-500/10 to-transparent backdrop-blur-md rounded-2xl p-4 border border-red-500/20 text-left">
                        <p className="text-xs text-red-400 uppercase font-bold mb-2">Total Debt</p>
                        <div className="text-3xl font-black text-red-300">${protocolStats.totalDebt}</div>
                        <p className="text-xs text-slate-500 mt-2">USDT borrowed</p>
                    </div>

                    <div className="bg-gradient-to-br from-yellow-500/10 to-transparent backdrop-blur-md rounded-2xl p-4 border border-yellow-500/20 text-left">
                        <p className="text-xs text-yellow-400 uppercase font-bold mb-2">Utilization</p>
                        <div className="text-3xl font-black text-yellow-300">{protocolStats.utilization}%</div>
                        <div className="w-full h-1 bg-slate-700 rounded-full mt-2 overflow-hidden">
                            <div className={`h-full transition-all ${parseFloat(protocolStats.utilization) > 80 ? 'bg-red-500' :
                                    parseFloat(protocolStats.utilization) > 60 ? 'bg-yellow-500' :
                                        'bg-green-500'
                                }`} style={{ width: `${Math.min(parseFloat(protocolStats.utilization), 100)}%` }} />
                        </div>
                    </div>

                    <div className="bg-gradient-to-br from-orange-500/10 to-transparent backdrop-blur-md rounded-2xl p-4 border border-orange-500/20 text-left">
                        <p className="text-xs text-orange-400 uppercase font-bold mb-2">Interest Rate</p>
                        <div className="text-3xl font-black text-orange-300">{protocolStats.interestRate}%</div>
                        <p className="text-xs text-slate-500 mt-2">APY</p>
                    </div>
                </div>

                <main className="grid grid-cols-1 md:grid-cols-12 gap-6">
                    <div className="md:col-span-7 space-y-6">
                        {/* RECEIPT TOKENS */}
                        <div className="bg-gradient-to-br from-white/[0.05] to-white/[0.02] backdrop-blur-md rounded-[2rem] p-8 border border-white/10 flex flex-col justify-center min-h-[220px] text-left">
                            <p className="text-blue-400 text-sm font-bold uppercase mb-2 tracking-widest">Your Position</p>
                            <div className="flex items-end gap-4">
                                <div>
                                    <p className="text-slate-400 text-xs uppercase font-semibold mb-1">mRWA-USDT Receipt</p>
                                    <h2 className="text-5xl md:text-6xl font-black tracking-tight text-white">
                                        {vUsdtRaw ? parseFloat(formatUnits(vUsdtRaw, 18)).toFixed(2) : '0.00'}
                                    </h2>
                                </div>
                            </div>
                            <p className="text-xs text-slate-400 mt-4">Receipt tokens earn 5% APY and represent your collateral position</p>
                        </div>

                        {/* PORTFOLIO BREAKDOWN */}
                        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                            <div className="bg-white/[0.02] backdrop-blur-md rounded-3xl p-5 border border-green-500/20 text-left">
                                <p className="text-sm text-green-400 uppercase font-bold mb-2 flex items-center gap-1">
                                    📊 Deposits
                                </p>
                                <p className="text-4xl font-bold text-green-400">{usdtBalance}</p>
                                <p className="text-xs text-slate-500 mt-2">Available USDT</p>
                            </div>

                            <div className="bg-white/[0.02] backdrop-blur-md rounded-3xl p-5 border border-purple-500/20 text-left">
                                <p className="text-sm text-purple-400 uppercase font-bold mb-2 flex items-center gap-1">
                                    💰 Borrowing
                                </p>
                                <p className="text-4xl font-bold text-purple-400">${borrowable}</p>
                                <p className="text-xs text-slate-500 mt-2">Borrow Capacity</p>
                            </div>

                            <div className="bg-white/[0.02] backdrop-blur-md rounded-3xl p-5 border border-orange-500/20 text-left">
                                <p className="text-sm text-orange-400 uppercase font-bold mb-2 flex items-center gap-1">
                                    ⚡ Fee
                                </p>
                                <p className="text-4xl font-bold text-orange-400">5% APY</p>
                                <p className="text-xs text-slate-500 mt-2">Interest Rate</p>
                            </div>
                        </div>
                    </div>

                    {/* CONTROL PANEL */}
                    <div className="md:col-span-5 bg-gradient-to-br from-blue-500/[0.08] to-purple-500/[0.05] backdrop-blur-xl rounded-[2.5rem] p-7 border border-blue-500/20 shadow-2xl text-left">
                        <div className="flex items-center justify-between mb-6">
                            <h3 className="text-2xl font-black">Control Panel</h3>
                            <button onClick={() => { fetchBalances(); refetchShares(); }} className="text-xs bg-white/5 border border-white/10 px-3 py-1 rounded-lg hover:bg-white/10 transition-all">↻ Refresh</button>
                        </div>

                        {/* TAB NAVIGATION */}
                        <div className="grid grid-cols-4 gap-2 mb-6 bg-white/5 p-2 rounded-xl border border-white/10">
                            {['deposit', 'borrow', 'withdraw', 'repay'].map(tab => (
                                <button
                                    key={tab}
                                    onClick={() => { setActiveTab(tab); reset(); }}
                                    className={`py-2 px-2 rounded-lg text-xs font-bold uppercase transition-all ${activeTab === tab
                                            ? 'bg-blue-600 text-white'
                                            : 'bg-transparent text-slate-400 hover:text-white'
                                        }`}
                                >
                                    {tab}
                                </button>
                            ))}
                        </div>

                        <div className="min-h-[60px] mb-6"><StatusMessage /></div>

                        {/* DEPOSIT TAB */}
                        {activeTab === 'deposit' && (
                            <div className="space-y-3">
                                <div className={`bg-slate-900/60 p-4 rounded-2xl border ${depositError ? 'border-red-500/50' : 'border-white/10'}`}>
                                    <label className="text-base text-slate-500 block mb-2 uppercase font-bold">Amount (USDT)</label>
                                    <input type="number" value={depositAmount} onChange={(e) => setDepositAmount(e.target.value)} placeholder="0.00" className="bg-transparent text-2xl w-full outline-none text-white font-semibold" />
                                </div>
                                <div className="grid grid-cols-2 gap-2">
                                    <button onClick={() => executeAction('approve')} disabled={isPending || isConfirming || inputDeposit <= 0} className={`py-3 border rounded-lg text-base font-bold transition-all uppercase tracking-tighter ${vaultApproved ? 'bg-green-600/30 border-green-500/50 text-green-400' : 'bg-white/5 border-white/10 text-white hover:bg-white/10'
                                        } disabled:opacity-20`}>{vaultApproved ? '✓ Approved' : 'Approve'}</button>
                                    <button onClick={() => executeAction('deposit')} disabled={isPending || isConfirming || depositError || depositApprovalError || inputDeposit <= 0} className="py-3 bg-gradient-to-r from-green-600 to-emerald-600 rounded-lg text-base font-bold hover:from-green-500 hover:to-emerald-500 disabled:opacity-20 transition-all uppercase tracking-tighter">Deposit</button>
                                </div>
                                {depositApprovalError && <p className="text-xs text-yellow-400 flex items-center gap-1">⚠️ Approve USDT first</p>}
                                <button onClick={() => executeAction('approveLeverage')} disabled={isPending || isConfirming || inputDeposit <= 0} className={`w-full py-3 rounded-lg text-sm font-black uppercase tracking-widest transition-all ${integratorApproved ? 'bg-orange-600/30 border border-orange-500/50 text-orange-400' : 'bg-orange-600/20 border border-orange-500/40 text-orange-400 hover:bg-orange-500/30'
                                    } disabled:opacity-20`}>{integratorApproved ? '✓ Leverage Ready' : '⚡ Approve & Leverage'}</button>
                            </div>
                        )}

                        {/* BORROW TAB */}
                        {activeTab === 'borrow' && (
                            <div className="space-y-3">
                                <div className={`bg-slate-900/60 p-4 rounded-2xl border ${borrowError ? 'border-red-500/50' : 'border-white/10'}`}>
                                    <label className="text-base text-slate-500 block mb-2 uppercase font-bold">Borrow Amount (USDT)</label>
                                    <input type="number" value={borrowAmount} onChange={(e) => setBorrowAmount(e.target.value)} placeholder="0.00" className="bg-transparent text-2xl w-full outline-none text-white font-semibold" />
                                </div>
                                <p className="text-base text-slate-500">Max: ${borrowable} | Interest: 5% APY</p>
                                <button onClick={() => executeAction('borrow')} disabled={isPending || isConfirming || inputBorrow <= 0} className="w-full py-3 bg-gradient-to-r from-purple-600 to-violet-600 rounded-lg font-bold hover:from-purple-500 hover:to-violet-500 disabled:opacity-20 transition-all uppercase text-base">Borrow USDT</button>
                            </div>
                        )}

                        {/* WITHDRAW TAB */}
                        {activeTab === 'withdraw' && (
                            <div className="space-y-3">
                                <div className={`bg-slate-900/60 p-4 rounded-2xl border ${withdrawError ? 'border-red-500/50' : 'border-white/10'}`}>
                                    <label className="text-base text-slate-500 block mb-2 uppercase font-bold">Withdraw Amount</label>
                                    <input type="number" value={withdrawAmount} onChange={(e) => setWithdrawAmount(e.target.value)} placeholder="0.00" className="bg-transparent text-2xl w-full outline-none text-white font-semibold" />
                                </div>
                                <p className="text-base text-slate-500">Max: ${borrowable} | Keep LTV {"<"} 80%</p>
                                <button onClick={() => executeAction('withdraw')} disabled={isPending || isConfirming || withdrawError || inputWithdraw <= 0} className="w-full py-3 bg-gradient-to-r from-blue-600 to-cyan-600 rounded-lg font-bold hover:from-blue-500 hover:to-cyan-500 disabled:opacity-20 transition-all uppercase text-base">Withdraw Collateral</button>
                            </div>
                        )}

                        {/* REPAY TAB */}
                        {activeTab === 'repay' && (
                            <div className="space-y-3">
                                {/* Oracle Status */}
                                <div className={`bg-slate-900/40 p-3 rounded-xl border ${oracleStatus.isConnected ? 'border-green-500/30' : 'border-yellow-500/30'}`}>
                                    <p className="text-xs text-slate-400 uppercase font-bold mb-1">Oracle Status</p>
                                    <div className="flex items-center gap-2">
                                        <div className={`w-2 h-2 rounded-full ${oracleStatus.isConnected ? 'bg-green-400' : 'bg-yellow-400'}`} />
                                        <span className="text-sm font-semibold">
                                            {oracleStatus.isConnected ? '✓ Chainlink Connected' : '⚠ Fallback Mode'}
                                        </span>
                                    </div>
                                </div>

                                {/* Token Selector */}
                                <div className="bg-slate-900/60 p-4 rounded-2xl border border-white/10">
                                    <label className="text-base text-slate-500 block mb-2 uppercase font-bold">Repay Token</label>
                                    <select 
                                        value={repayToken} 
                                        onChange={(e) => setRepayToken(e.target.value)}
                                        className="w-full bg-slate-800/60 text-white p-2 rounded-lg border border-white/10 focus:border-blue-500 outline-none text-sm font-semibold"
                                    >
                                        <option value="usdt">USDT (Direct)</option>
                                        {allowedBorrowTokens.map(token => (
                                            <option key={token} value={token}>
                                                Borrow Token ({token.slice(0, 8)}...)
                                            </option>
                                        ))}
                                    </select>
                                </div>

                                {/* Amount Input */}
                                <div className={`bg-slate-900/60 p-4 rounded-2xl border ${repayError ? 'border-red-500/50' : 'border-white/10'}`}>
                                    <label className="text-base text-slate-500 block mb-2 uppercase font-bold">
                                        {repayToken === 'usdt' ? 'Repay Amount (USDT)' : 'Repay Amount (Token)'}
                                    </label>
                                    <input type="number" value={repayAmount} onChange={(e) => setRepayAmount(e.target.value)} placeholder="0.00" className="bg-transparent text-2xl w-full outline-none text-white font-semibold" />
                                </div>
                                <p className="text-base text-slate-500">Debt: ${healthData.debt} | Available: {usdtBalance}</p>
                                <button onClick={() => executeAction('repay')} disabled={isPending || isConfirming || repayError || inputRepay <= 0} className="w-full py-3 bg-gradient-to-r from-red-600 to-pink-600 rounded-lg font-bold hover:from-red-500 hover:to-pink-500 disabled:opacity-20 transition-all uppercase text-base">
                                    {repayToken === 'usdt' ? 'Repay with USDT' : 'Repay with Borrow Token'}
                                </button>
                            </div>
                        )}
                    </div>
                </main>

                {/* FOOTER */}
                <footer className="w-full mt-12 mb-6 pt-6 border-t border-white/5 flex flex-col md:flex-row justify-between items-center gap-4 text-xs text-slate-500 font-mono">
                    <div className="flex flex-col md:flex-row gap-6 text-center md:text-left">
                        <div className="flex flex-col"><span className="uppercase font-bold text-slate-400 text-xs">Vault</span><a href={`${MANTLE_SEPOLIA.blockExplorers.default.url}/address/${VAULT_ADDRESS}`} target="_blank" rel="noreferrer" className="hover:text-blue-400 underline break-all">{VAULT_ADDRESS.slice(0, 16)}...</a></div>
                        <div className="flex flex-col"><span className="uppercase font-bold text-slate-400 text-xs">USDT Token</span><a href={`${MANTLE_SEPOLIA.blockExplorers.default.url}/address/${USDT_ADDRESS}`} target="_blank" rel="noreferrer" className="hover:text-blue-400 underline break-all">{USDT_ADDRESS.slice(0, 16)}...</a></div>
                        <div className="flex flex-col"><span className="uppercase font-bold text-slate-400 text-xs">Integrator</span><a href={`${MANTLE_SEPOLIA.blockExplorers.default.url}/address/${INTEGRATOR_ADDRESS}`} target="_blank" rel="noreferrer" className="hover:text-blue-400 underline">{INTEGRATOR_ADDRESS.slice(0, 16)}...</a></div>
                    </div>
                    <div className="text-center"><span className="text-slate-400 font-bold">⚡ Powered by Mantle Sepolia</span></div>
                </footer>
            </div>
        </div>
    );
}
