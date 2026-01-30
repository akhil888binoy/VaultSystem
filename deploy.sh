#!/bin/bash
set -euo pipefail

# Load env variables
source .env

: "${BASE_SEPOLIA_RPC:?Missing BASE_SEPOLIA_RPC}"
: "${BASESCAN_API_KEY:?Missing BASESCAN_API_KEY}"

echo "Starting deployment on Base mainnet..."
echo "RPC: $BASE_SEPOLIA_RPC"
echo "------------------------------------------"

forge script script/DeployScript.s.sol:DeployScript \
  --rpc-url "$BASE_SEPOLIA_RPC" \
  --broadcast \
  --verify \
  --etherscan-api-key "$BASESCAN_API_KEY" \
  --legacy

echo "------------------------------------------"
echo "Deployment complete. Verifying all deployed contracts..."

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required for post-deploy verification."
  exit 1
fi

CHAIN_ID=8453
RUN_JSON="broadcast/DeployScript.s.sol/${CHAIN_ID}/run-latest.json"

if [ ! -f "$RUN_JSON" ]; then
  echo "Error: $RUN_JSON not found. Cannot verify."
  exit 1
fi

role_manager=$(jq -r '.transactions[] | select(.contractName=="RoleManager" and .transactionType=="CREATE") | .contractAddress' "$RUN_JSON" | tail -n1)
role_manager_admin=$(jq -r '.transactions[] | select(.contractName=="RoleManager" and .transactionType=="CREATE") | .arguments[0]' "$RUN_JSON" | tail -n1)
timelock=$(jq -r '.transactions[] | select(.contractName=="Timelock" and .transactionType=="CREATE") | .contractAddress' "$RUN_JSON" | tail -n1)
wallet_router=$(jq -r '.transactions[] | select(.contractName=="WalletRouter" and .transactionType=="CREATE") | .contractAddress' "$RUN_JSON" | tail -n1)
vault_impl=$(jq -r '.transactions[] | select(.contractName=="Vault" and .transactionType=="CREATE") | .contractAddress' "$RUN_JSON" | tail -n1)
vault_proxy=$(jq -r '.transactions[] | select(.contractName=="ERC1967Proxy" and .transactionType=="CREATE") | .contractAddress' "$RUN_JSON" | tail -n1)
vault_init=$(jq -r '.transactions[] | select(.contractName=="ERC1967Proxy" and .transactionType=="CREATE") | .arguments[1]' "$RUN_JSON" | tail -n1)

if [ -z "$role_manager" ] || [ -z "$role_manager_admin" ] || [ -z "$timelock" ] || [ -z "$wallet_router" ] || [ -z "$vault_impl" ] || [ -z "$vault_proxy" ] || [ -z "$vault_init" ]; then
  echo "Error: Could not read deployed addresses from $RUN_JSON"
  exit 1
fi

forge verify-contract --chain base --etherscan-api-key "$BASESCAN_API_KEY" \
  "$role_manager" contracts/access/RoleManager.sol:RoleManager \
  --constructor-args "$(cast abi-encode "constructor(address)" "$role_manager_admin")"

forge verify-contract --chain base --etherscan-api-key "$BASESCAN_API_KEY" \
  "$timelock" contracts/timelock/Timelock.sol:Timelock \
  --constructor-args "$(cast abi-encode "constructor(address)" "$role_manager")"

forge verify-contract --chain base --etherscan-api-key "$BASESCAN_API_KEY" \
  "$wallet_router" contracts/router/WalletRouter.sol:WalletRouter \
  --constructor-args "$(cast abi-encode "constructor(address,address)" "$role_manager" "$timelock")"

forge verify-contract --chain base --etherscan-api-key "$BASESCAN_API_KEY" \
  "$vault_impl" contracts/vault/Vault.sol:Vault

forge verify-contract --chain base --etherscan-api-key "$BASESCAN_API_KEY" \
  "$vault_proxy" lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --constructor-args "$(cast abi-encode "constructor(address,bytes)" "$vault_impl" "$vault_init")"

echo "✅ Deployment finished!"
