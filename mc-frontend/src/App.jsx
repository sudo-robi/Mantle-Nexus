import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import {
  WagmiProvider,
  http
} from "wagmi";
import {
  getDefaultConfig,
  RainbowKitProvider
} from '@rainbow-me/rainbowkit';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

import '@rainbow-me/rainbowkit/styles.css';
import './index.css';

import { MANTLE_SEPOLIA } from './constants';
import Dashboard from './components/Dashboard';
import Tutorial from './components/Tutorial';

const config = getDefaultConfig({
  appName: 'MC Vault',
  projectId: '0cfa61163309d825276ed94521b8b6ab',
  chains: [MANTLE_SEPOLIA],
  transports: { [MANTLE_SEPOLIA.id]: http() },
});

const queryClient = new QueryClient();

export default function App() {
  return (
    <Router>
      <QueryClientProvider client={queryClient}>
        <WagmiProvider config={config}>
          <RainbowKitProvider modalSize="compact">
            <Routes>
              <Route path="/" element={<Dashboard />} />
              <Route path="/tutorial" element={<Tutorial />} />
            </Routes>
          </RainbowKitProvider>
        </WagmiProvider>
      </QueryClientProvider>
    </Router>
  );
}