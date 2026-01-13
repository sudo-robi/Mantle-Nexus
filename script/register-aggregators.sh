#!/usr/bin/env bash
set -euo pipefail

RPC_URL=${RPC_URL:-http://localhost:8545}
ORACLE_ADDRESS=${ORACLE_ADDRESS:-}
PRIVATE_KEY=${PRIVATE_KEY:-}

if [ -z "$ORACLE_ADDRESS" ] || [ -z "$PRIVATE_KEY" ]; then
  echo "Usage: ORACLE_ADDRESS=0x... PRIVATE_KEY=0x... RPC_URL=... ./script/register-aggregators.sh ASSET_1 AGG_1 DECIMALS_1 [ASSET_2 AGG_2 DECIMALS_2 ...]"
  exit 1
fi

if [ $# -lt 3 ]; then
  echo "Provide at least one asset/aggregator/decimals triple"
  exit 1
fi

echo "Registering aggregators on oracle: $ORACLE_ADDRESS"

while [ $# -gt 0 ]; do
  ASSET=$1; AGG=$2; DEC=$3
  shift 3

  echo "Setting aggregator for $ASSET -> $AGG (decimals $DEC)"
  cast send "$ORACLE_ADDRESS" "setAggregator(address,address,uint8)" "$ASSET" "$AGG" "$DEC" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
done

echo "Done."
