#!/bin/bash
set -e

# Load env variables
source .env

echo "Starting deployment on Base mainnet..."
echo "RPC: $BASE_MAINNET_RPC_URL"
echo "------------------------------------------"

forge script script/DeployScript.s.sol:DeployScript \
  --rpc-url "$BASE_MAINNET_RPC_URL" \
  --broadcast \
  --verify \
  --etherscan-api-key "$BASESCAN_API_KEY" \
  --legacy

echo "------------------------------------------"
echo "✅ Deployment finished!"
