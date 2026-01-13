#!/bin/bash

# MC-RWA Vault: Complete Demo Setup & Walkthrough
# This script guides you through the entire workflow:
# 1. Deploy contracts
# 2. Setup oracle with Chainlink feeds
# 3. Execute demo transactions
# 4. Monitor events

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         MC-RWA Vault: Complete Demo Setup v2.0             ║${NC}"
echo -e "${BLUE}║        (Now with Chainlink Oracle Integration)             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check environment
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}✗ PRIVATE_KEY not set${NC}"
    echo "Set your private key: export PRIVATE_KEY=0x..."
    exit 1
fi

if [ -z "$RPC_URL" ]; then
    RPC_URL="https://5003.rpc.thirdweb.com"
    echo -e "${YELLOW}Using default RPC: $RPC_URL${NC}"
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Private Key: ${PRIVATE_KEY:0:10}..."
echo "  RPC URL: ${RPC_URL:0:40}..."
echo ""

# Step 1: Run tests
echo -e "${BLUE}Step 1: Running test suite (41 tests)${NC}"
forge test --silent
echo -e "${GREEN}✓ All tests passed${NC}"
echo ""

# Step 2: Deploy contracts (if not already deployed)
echo -e "${BLUE}Step 2: Build contracts${NC}"
forge build --quiet
echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Step 3: Oracle deployment
echo -e "${BLUE}Step 3: Oracle Setup Instructions${NC}"
echo ""
echo "To deploy the oracle and register Chainlink feeds, run:"
echo ""
echo -e "${YELLOW}export USDT_ADDRESS=0x915cC86fE0871835e750E93e025080FFf9927A3f${NC}"
echo -e "${YELLOW}export VAULT_ADDRESS=0x61dAF0E077555362ea135C1C56c808aA8b0e71F8${NC}"
echo -e "${YELLOW}export PRIVATE_KEY=0x...${NC}"
echo -e "${YELLOW}export RPC_URL=https://5003.rpc.thirdweb.com${NC}"
echo ""
echo -e "${BLUE}./script/deploy-oracle-full.sh${NC}"
echo ""

# Step 4: Multi-token demo
echo -e "${BLUE}Step 4: New Features - Multi-Token Repayment${NC}"
echo ""
echo "In the frontend, you can now:"
echo "  ✓ Deposit USDT as collateral"
echo "  ✓ Borrow USDT"
echo "  ✓ Repay with USDT OR any allowed borrow token"
echo "  ✓ View oracle status (Chainlink connected / Fallback mode)"
echo ""

# Step 5: Monitoring
echo -e "${BLUE}Step 5: Monitor Oracle Events${NC}"
echo ""
echo "To watch oracle events in real-time, run:"
echo ""
echo -e "${YELLOW}export ORACLE_ADDRESS=0x...  # From deploy-oracle-full.sh output${NC}"
echo -e "${BLUE}./script/monitor-oracle.sh${NC}"
echo ""

# Step 6: Frontend
echo -e "${BLUE}Step 6: Start Frontend${NC}"
echo ""
echo "Run the React frontend:"
echo ""
echo -e "${YELLOW}cd mc-rwa-frontend${NC}"
echo -e "${YELLOW}npm run dev${NC}"
echo ""

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}✓ DEMO SETUP COMPLETE${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Deploy oracle: ./script/deploy-oracle-full.sh"
echo "  2. Monitor events: ./script/monitor-oracle.sh"
echo "  3. Launch frontend: cd mc-rwa-frontend && npm run dev"
echo "  4. Execute demo workflow on localhost:5173"
echo ""
echo -e "${GREEN}All systems ready! 🚀${NC}"
