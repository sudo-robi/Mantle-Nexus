#!/bin/bash

# MC-RWA Vault: Oracle Event Monitoring
# Monitors on-chain events for oracle staleness, price updates, and aggregator registration
# Run this to watch real-time oracle activity for monitoring and alerting

set -e

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          MC-RWA Vault: Oracle Event Monitor                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# Verify environment
if [ -z "$ORACLE_ADDRESS" ] || [ -z "$RPC_URL" ]; then
    echo -e "${RED}Error: ORACLE_ADDRESS and RPC_URL required${NC}"
    echo "Usage:"
    echo "  export ORACLE_ADDRESS=0x..."
    echo "  export RPC_URL=https://..."
    echo "  ./script/monitor-oracle.sh"
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Oracle: ${ORACLE_ADDRESS:0:16}..."
echo "  RPC: ${RPC_URL:0:30}..."
echo ""

# Event signatures (keccak256 hashes)
PRICE_UPDATED_SIGNATURE="0x$(cast keccak "PriceUpdated(address,uint256,uint256,bool)" | cut -c 3-)"
STALENESS_DETECTED_SIGNATURE="0x$(cast keccak "PriceStalenessDetected(address,uint256,uint256)" | cut -c 3-)"
AGGREGATOR_REGISTERED_SIGNATURE="0x$(cast keccak "AggregatorRegistered(address,address,uint8)" | cut -c 3-)"
FALLBACK_PRICE_SIGNATURE="0x$(cast keccak "FallbackPriceUpdated(address,uint256)" | cut -c 3-)"

echo -e "${BLUE}[Monitoring] Listening for oracle events...${NC}"
echo ""

# Function to monitor PriceUpdated events
monitor_price_updates() {
    echo -e "${YELLOW}▶ Price Updates:${NC}"
    cast logs \
        --address "$ORACLE_ADDRESS" \
        --logs-filter "$PRICE_UPDATED_SIGNATURE" \
        --from-block 0 \
        --to-block latest \
        --rpc-url "$RPC_URL" 2>/dev/null | head -10 || echo "  (No price updates yet)"
    echo ""
}

# Function to monitor staleness detection
monitor_staleness() {
    echo -e "${RED}▶ Staleness Events:${NC}"
    cast logs \
        --address "$ORACLE_ADDRESS" \
        --logs-filter "$STALENESS_DETECTED_SIGNATURE" \
        --from-block 0 \
        --to-block latest \
        --rpc-url "$RPC_URL" 2>/dev/null | head -10 || echo "  (No staleness detected - Oracle is healthy)"
    echo ""
}

# Function to monitor aggregator registration
monitor_aggregators() {
    echo -e "${GREEN}▶ Aggregator Registrations:${NC}"
    cast logs \
        --address "$ORACLE_ADDRESS" \
        --logs-filter "$AGGREGATOR_REGISTERED_SIGNATURE" \
        --from-block 0 \
        --to-block latest \
        --rpc-url "$RPC_URL" 2>/dev/null | head -10 || echo "  (No aggregators registered)"
    echo ""
}

# Function to monitor fallback price updates
monitor_fallback() {
    echo -e "${YELLOW}▶ Fallback Price Updates:${NC}"
    cast logs \
        --address "$ORACLE_ADDRESS" \
        --logs-filter "$FALLBACK_PRICE_SIGNATURE" \
        --from-block 0 \
        --to-block latest \
        --rpc-url "$RPC_URL" 2>/dev/null | head -10 || echo "  (No fallback updates)"
    echo ""
}

# Run all monitors
monitor_price_updates
monitor_staleness
monitor_aggregators
monitor_fallback

echo -e "${BLUE}═════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Event monitoring complete${NC}"
echo ""
echo -e "${YELLOW}Event Descriptions:${NC}"
echo "  • PriceUpdated: Oracle returned a price (from Chainlink or fallback)"
echo "  • PriceStalenessDetected: Chainlink feed hasn't updated in 1+ hour"
echo "  • AggregatorRegistered: New Chainlink aggregator was registered"
echo "  • FallbackPriceUpdated: Fallback price was set (circuit breaker)"
echo ""
echo -e "${YELLOW}For real-time monitoring, use:${NC}"
echo "  cast rpc eth_subscribe logs --rpc-url ws://your-ws-endpoint"
echo ""
