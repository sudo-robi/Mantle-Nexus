#!/bin/bash

# MC-RWA Vault: Complete Oracle Deployment & Registration Orchestration
# This script deploys the ChainlinkPriceOracle, registers it with the vault,
# and sets up fallback prices and aggregators in a single orchestrated flow.

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display banner
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     MC-RWA Vault: Oracle Deployment Orchestration          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# Verify required environment variables
check_env() {
    if [ -z "${!1}" ]; then
        echo -e "${RED}✗ Error: $1 not set${NC}"
        exit 1
    fi
}

check_env PRIVATE_KEY
check_env RPC_URL
check_env USDT_ADDRESS
check_env VAULT_ADDRESS

echo -e "${YELLOW}► Configuration:${NC}"
echo -e "  RPC_URL: ${RPC_URL:0:30}..."
echo -e "  VAULT: ${VAULT_ADDRESS:0:16}..."
echo -e "  USDT: ${USDT_ADDRESS:0:16}..."
echo ""

# Step 1: Deploy Oracle Contract
echo -e "${BLUE}[Step 1/4] Deploying ChainlinkPriceOracle...${NC}"

DEPLOY_OUTPUT=$(forge script script/DeployOracle.s.sol:DeployOracle \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    2>&1)

echo "$DEPLOY_OUTPUT"

# Extract deployed oracle address from forge output
ORACLE_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -i "ChainlinkPriceOracle deployed" | awk '{print $NF}' || echo "")

if [ -z "$ORACLE_ADDRESS" ]; then
    ORACLE_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP '0x[a-fA-F0-9]{40}' | tail -1)
fi

if [ -z "$ORACLE_ADDRESS" ]; then
    echo -e "${RED}✗ Failed to extract oracle address from deployment${NC}"
    echo -e "${YELLOW}Deployment output:${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ ChainlinkPriceOracle deployed: $ORACLE_ADDRESS${NC}"
echo ""

# Step 2: Register Oracle with Vault
echo -e "${BLUE}[Step 2/4] Registering Oracle with Vault...${NC}"

TX_HASH=$(cast send "$VAULT_ADDRESS" "setOracle(address)" "$ORACLE_ADDRESS" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

echo -e "${GREEN}✓ Oracle registered (tx: ${TX_HASH:0:12})${NC}"
sleep 2

# Step 3: Set Fallback Price for USDT
echo -e "${BLUE}[Step 3/4] Setting USDT fallback price (\$1.00)...${NC}"

# Convert $1.00 to 18 decimals: 1000000000000000000
FALLBACK_PRICE="1000000000000000000"

TX_HASH=$(cast send "$ORACLE_ADDRESS" \
    "setChainlinkFallbackPrice(address,uint256)" \
    "$USDT_ADDRESS" \
    "$FALLBACK_PRICE" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

echo -e "${GREEN}✓ USDT fallback price set (tx: ${TX_HASH:0:12})${NC}"
sleep 2

# Step 4: Register Aggregators (if provided)
echo -e "${BLUE}[Step 4/4] Registering Chainlink Aggregators...${NC}"

if [ ! -z "$AGGREGATOR_DATA" ]; then
    # Parse aggregator data in format: ASSET_1:AGG_1:DECIMALS_1,ASSET_2:AGG_2:DECIMALS_2,...
    IFS=',' read -ra AGGREGATORS <<< "$AGGREGATOR_DATA"
    
    for agg_info in "${AGGREGATORS[@]}"; do
        IFS=':' read -r ASSET AGG DECIMALS <<< "$agg_info"
        
        if [ ! -z "$ASSET" ] && [ ! -z "$AGG" ] && [ ! -z "$DECIMALS" ]; then
            echo "  Registering aggregator for $ASSET..."
            
            TX_HASH=$(cast send "$ORACLE_ADDRESS" \
                "registerChainlinkAggregator(address,address,uint8)" \
                "$ASSET" \
                "$AGG" \
                "$DECIMALS" \
                --rpc-url "$RPC_URL" \
                --private-key "$PRIVATE_KEY" \
                --json | jq -r '.transactionHash')
            
            echo -e "    ${GREEN}✓ Registered (tx: ${TX_HASH:0:12})${NC}"
            sleep 1
        fi
    done
else
    echo -e "${YELLOW}  (No aggregators provided. Use AGGREGATOR_DATA env var to register them)${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}✓ ORACLE DEPLOYMENT COMPLETE${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Configuration to save:${NC}"
echo "  ORACLE_ADDRESS=$ORACLE_ADDRESS"
echo ""
echo -e "${YELLOW}For future aggregator registration, use:${NC}"
echo "  export ORACLE_ADDRESS=$ORACLE_ADDRESS"
echo "  export PRIVATE_KEY=<your_key>"
echo "  export RPC_URL=$RPC_URL"
echo "  ./script/register-aggregators.sh ASSET_1 AGG_1 DECIMALS_1 [...]"
echo ""
echo -e "${GREEN}Next: Test with \`forge test\` and deploy to mainnet when ready${NC}"
