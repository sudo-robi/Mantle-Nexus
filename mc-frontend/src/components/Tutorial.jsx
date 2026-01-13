import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';

export default function Tutorial() {
    const [step, setStep] = useState(0);

    const steps = [
        {
            title: "Welcome to MC-RWA Vault",
            content: (
                <div className="space-y-4 text-slate-300">
                    <p>
                        This tutorial will guide you through the basics of using the Multi-Collateral Real-World Asset Vault.
                    </p>
                    <div className="bg-blue-900/30 p-4 rounded-xl border border-blue-500/20">
                        <h4 className="font-bold text-blue-400 mb-2">What you'll learn:</h4>
                        <ul className="list-disc list-inside space-y-1 text-sm">
                            <li>How to deposit collateral</li>
                            <li>How to borrow USDT against your assets</li>
                            <li>Understanding Health Factors & Liquidation</li>
                            <li>How to repay your debt</li>
                        </ul>
                    </div>
                </div>
            )
        },
        {
            title: "Step 1: Deposit Collateral",
            content: (
                <div className="space-y-4 text-slate-300">
                    <p>
                        To borrow assets, you first need to provide collateral. We currently support <strong>USDT</strong> as the primary collateral.
                    </p>
                    <div className="bg-slate-800/50 p-6 rounded-xl border border-white/10 relative overflow-hidden">
                        <div className="absolute top-2 right-2 text-xs bg-slate-700 px-2 py-1 rounded">Simulation</div>
                        <label className="block text-xs uppercase font-bold text-slate-500 mb-1">Deposit Amount</label>
                        <div className="flex gap-2 mb-2">
                            <input disabled type="text" value="1000.00" className="bg-transparent border border-white/20 rounded p-2 w-full text-white" />
                            <button className="bg-green-600 text-white px-4 rounded font-bold text-sm">Deposit</button>
                        </div>
                        <p className="text-xs text-slate-400">
                            When you deposit, you receive <strong>mRWA-USDT</strong> receipt tokens that earn 5% APY automatically.
                        </p>
                    </div>
                </div>
            )
        },
        {
            title: "Step 2: Borrowing Power",
            content: (
                <div className="space-y-4 text-slate-300">
                    <p>
                        Once you have deposited collateral, you can borrow against it. The protocol allows a maximum <strong>50% LTV (Loan-To-Value)</strong>.
                    </p>
                    <div className="grid grid-cols-2 gap-4">
                        <div className="bg-purple-900/20 p-4 rounded-xl border border-purple-500/20 text-center">
                            <div className="text-2xl font-bold text-white">$1,000</div>
                            <div className="text-xs text-purple-300 uppercase font-bold">Collateral</div>
                        </div>
                        <div className="bg-green-900/20 p-4 rounded-xl border border-green-500/20 text-center">
                            <div className="text-2xl font-bold text-white">$500</div>
                            <div className="text-xs text-green-300 uppercase font-bold">Max Borrow</div>
                        </div>
                    </div>
                    <p className="text-sm">
                        For every $1.00 of collateral, you can borrow up to $0.50 of USDT.
                    </p>
                </div>
            )
        },
        {
            title: "Step 3: Health Factor & Risks",
            content: (
                <div className="space-y-4 text-slate-300">
                    <p>
                        Your <strong>Health Factor</strong> represents the safety of your loan.
                    </p>
                    <div className="flex justify-between text-xs font-bold uppercase mb-1">
                        <span className="text-red-500">Danger {'<'} 1.0</span>
                        <span className="text-green-500">Safe {'>'} 2.0</span>
                    </div>
                    <div className="h-4 bg-slate-700 rounded-full overflow-hidden flex">
                        <div className="w-1/3 bg-red-500"></div>
                        <div className="w-1/3 bg-yellow-500"></div>
                        <div className="w-1/3 bg-green-500"></div>
                    </div>
                    <p className="text-sm mt-2">
                        If your Health Factor drops below <strong>1.0</strong>, your collateral can be <strong>liquidated</strong> to repay the debt. Keep it above 2.0 to be safe!
                    </p>
                </div>
            )
        },
        {
            title: "Ready to Start?",
            content: (
                <div className="space-y-4 text-slate-300 text-center">
                    <div className="text-5xl mb-4">🚀</div>
                    <p>
                        You now understand the basics of the MC-RWA Vault.
                        Connect your wallet and start earning yield or borrowing assets today.
                    </p>
                    <Link to="/" className="inline-block bg-gradient-to-r from-blue-600 to-purple-600 text-white font-bold py-3 px-8 rounded-full hover:shadow-lg hover:shadow-blue-500/30 transition-all transform hover:scale-105">
                        Go to Dashboard
                    </Link>
                </div>
            )
        }
    ];

    const nextStep = () => {
        if (step < steps.length - 1) setStep(step + 1);
    };

    const prevStep = () => {
        if (step > 0) setStep(step - 1);
    };

    return (
        <div className="min-h-screen w-full bg-slate-950 flex flex-col items-center justify-center p-4 relative overflow-hidden">
            {/* Background Ambience */}
            <div className="absolute top-0 left-0 w-full h-full overflow-hidden z-0">
                <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-blue-600/20 blur-[100px] rounded-full animate-pulse" />
                <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-purple-600/20 blur-[100px] rounded-full animate-pulse" style={{ animationDelay: '1s' }} />
            </div>

            <div className="absolute top-8 left-8 z-20">
                <Link to="/" className="text-slate-400 hover:text-white flex items-center gap-2 transition-colors">
                    ← Back to Dashboard
                </Link>
            </div>

            <div className="relative z-10 max-w-2xl w-full">
                <AnimatePresence mode="wait">
                    <motion.div
                        key={step}
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -20 }}
                        transition={{ duration: 0.3 }}
                        className="bg-slate-900/80 backdrop-blur-xl border border-white/10 rounded-3xl p-8 md:p-12 shadow-2xl"
                    >
                        <div className="flex justify-between items-center mb-8">
                            <h2 className="text-2xl md:text-3xl font-black text-white tracking-tight">{steps[step].title}</h2>
                            <span className="text-slate-500 font-mono text-sm">Step {step + 1}/{steps.length}</span>
                        </div>

                        <div className="min-h-[200px] flex flex-col justify-center">
                            {steps[step].content}
                        </div>

                        <div className="flex justify-between mt-12 pt-8 border-t border-white/5">
                            <button
                                onClick={prevStep}
                                disabled={step === 0}
                                className={`text-sm font-bold uppercase tracking-wider px-6 py-3 rounded-lg transition-all ${step === 0 ? 'opacity-0 cursor-default' : 'text-slate-400 hover:bg-white/5 hover:text-white'}`}
                            >
                                Previous
                            </button>

                            {step < steps.length - 1 ? (
                                <button
                                    onClick={nextStep}
                                    className="bg-white text-slate-900 font-bold uppercase tracking-wider px-8 py-3 rounded-lg hover:bg-blue-50 transition-all hover:scale-105"
                                >
                                    Next Step
                                </button>
                            ) : (
                                <Link to="/" className="bg-green-500 text-white font-bold uppercase tracking-wider px-8 py-3 rounded-lg hover:bg-green-400 transition-all hover:scale-105">
                                    Finish
                                </Link>
                            )}
                        </div>
                    </motion.div>
                </AnimatePresence>

                {/* Progress Indicators */}
                <div className="flex justify-center gap-2 mt-8">
                    {steps.map((_, i) => (
                        <div
                            key={i}
                            className={`h-1.5 rounded-full transition-all duration-300 ${i === step ? 'w-8 bg-blue-500' : 'w-2 bg-slate-700'}`}
                        />
                    ))}
                </div>
            </div>
        </div>
    );
}
