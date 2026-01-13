#!/bin/bash

# MC-RWA Vault - Quick Demo Setup Script
# This script sets up test data on Mantle Sepolia for judges to see non-zero values

VAULT_ADDRESS="0x40776dF7BB64828BfaFBE4cfacFECD80fED34266"
USDT_ADDRESS="0x915cC86fE0871835e750E93e025080FFf9927A3f"
PRIVATE_KEY="${1:-}"
RPC_URL="https://rpc.sepolia.mantle.xyz"

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: Please provide your private key as an argument"
    echo ""
    echo "Usage: ./setup-demo.sh 0x..."
    echo ""
    echo "This script will:"
    echo "  1. Mint 10,000 USDT to your wallet"
    echo "  2. Approve the vault to spend USDT"
    echo "  3. Deposit 5,000 USDT as collateral"
    echo "  4. Borrow 1,500 USDT against collateral"
    echo ""
    echo "This will populate the dashboard with:"
    echo "  ✓ Health Factor: ~1.67"
    echo "  ✓ LTV Ratio: 30%"
    echo "  ✓ Collateral: $5,000 USD"
    echo "  ✓ Total Debt: $1,500 USDT"
    echo ""
    echo "Your wallet will need ~0.1 MNT for gas"
    exit 1
fi

echo "🚀 MC-RWA Vault Demo Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Setting up demo with private key: ${PRIVATE_KEY:0:10}..."
echo ""

# Step 1: Mint USDT
echo "📝 Step 1: Minting 10,000 USDT..."
echo "Command:"
echo "cast send $USDT_ADDRESS \"mint(address,uint256)\" \$(cast wallet address --private-key $PRIVATE_KEY) 10000000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY"
echo ""

cast send $USDT_ADDRESS "mint(address,uint256)" $(cast wallet address --private-key $PRIVATE_KEY) 10000000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY

echo "✓ Minted successfully"
echo ""
sleep 2

# Step 2: Approve
echo "📝 Step 2: Approving vault to spend USDT..."
echo "Command:"
echo "cast send $USDT_ADDRESS \"approve(address,uint256)\" $VAULT_ADDRESS 5000000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY"
echo ""

cast send $USDT_ADDRESS "approve(address,uint256)" $VAULT_ADDRESS 5000000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY

echo "✓ Approved successfully"
echo ""
sleep 2

# Step 3: Deposit
echo "📝 Step 3: Depositing 5,000 USDT as collateral..."
echo "Command:"
echo "cast send $VAULT_ADDRESS \"depositERC20(address,uint256)\" $USDT_ADDRESS 5000000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY"
echo ""

cast send $VAULT_ADDRESS "depositERC20(address,uint256)" $USDT_ADDRESS 5000000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY

echo "✓ Deposited successfully"
echo ""
sleep 2

# Step 4: Borrow
echo "📝 Step 4: Borrowing 1,500 USDT against collateral..."
echo "Command:"
echo "cast send $VAULT_ADDRESS \"borrow(uint256)\" 1500000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY"
echo ""

cast send $VAULT_ADDRESS "borrow(uint256)" 1500000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY

echo "✓ Borrowed successfully"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Demo Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your dashboard should now show:"
echo "  ✓ Health Factor: ~1.67 (Yellow warning)"
echo "  ✓ LTV Ratio: 30%"
echo "  ✓ Collateral: $5,000 USD"
echo "  ✓ Total Debt: $1,500 USDT (with 5% APY interest)"
echo "  ✓ Receipt Tokens (mRWA-USDT): 5,000"
echo ""
echo "🎉 Perfect for judges to see a working system!"
echo ""
