
# Vault System Smart Contracts

This repository, [Avitus-Labs/portal-wallet-contracts](https://github.com/Avitus-Labs/portal-wallet-contracts), contains a set of Ethereum smart contracts implementing a secure vault system for managing deposits and withdrawals of ETH and ERC20 tokens. The system is built with role-based access control, timelock mechanisms, and upgradeability, using Foundry for development, deployment, and testing.

## Overview

The vault system consists of five main contracts and interfaces:

1. **RoleManager.sol**: Manages roles (`OPERATOR_ROLE`, `VAULT_ADMIN_ROLE`, `ROUTER_ADMIN_ROLE`, `DEFAULT_ADMIN_ROLE`) with timelocked role changes and admin transfers, designed for multi-signature wallet control.
2. **WalletRouter.sol**: Routes deposits and withdrawals to the vault, with role-based access and pausability.
3. **Vault.sol**: Manages deposits and withdrawals of supported tokens (ETH and ERC20), using the UUPS proxy pattern for upgradeability.
4. **Timelock.sol**: Enforces a 24-hour timelock for sensitive operations, such as setting a new WalletRouter or recovering funds.
5. **Interfaces (IRoleManager.sol, ITimelock.sol, IVault.sol)**: Define external interfaces for interacting with the contracts.

The system leverages OpenZeppelin's libraries (version 4.9.3) for access control, reentrancy protection, pausability, and safe token handling.

## Features

- **Role-Based Access Control**: Uses OpenZeppelin's `AccessControl` for role management, with timelocked changes.
- **Timelock Mechanism**: Sensitive operations (role changes, token additions/removals, WalletRouter updates, fund recovery) require a 24-hour timelock.
- **Upgradeability**: The `Vault` contract uses the UUPS proxy pattern, controlled by `VAULT_ADMIN_ROLE`.
- **Pausability**: `WalletRouter` and `Vault` can be paused to halt operations during emergencies.
- **ETH and ERC20 Support**: Supports deposits and withdrawals of ETH and ERC20 tokens, with balance tracking.
- **Reentrancy Protection**: Uses `ReentrancyGuard` to prevent reentrancy attacks.
- **Event Tracking**: Emits events for deposits, withdrawals, role changes, token support changes, and timelock actions.

## Contracts and Their Roles

### RoleManager.sol
- **Purpose**: Manages role assignments with timelock delays.
- **Key Functions**:
  - `proposeGrantRole` / `proposeRevokeRole`: Propose role changes.
  - `executeRoleAction`: Execute role changes after timelock.
  - `proposeAdminTransfer` / `acceptAdminTransfer`: Transfer admin role.
  - `pause` / `unpause`: Control role management operations.
  - `setTimelock`: Adjust timelock delay period.
- **Roles**:
  - `DEFAULT_ADMIN_ROLE`: Manages all roles and pausing.
  - `OPERATOR_ROLE`: Authorizes withdrawals.
  - `VAULT_ADMIN_ROLE`: Manages vault operations.
  - `ROUTER_ADMIN_ROLE`: Manages WalletRouter settings.

### WalletRouter.sol
- **Purpose**: Routes deposits and withdrawals to the vault.
- **Key Functions**:
  - `deposit`: Deposits ETH or ERC20 tokens.
  - `withdraw`: Withdraws funds (requires `OPERATOR_ROLE`).
  - `setVault`: Sets the vault address (requires `ROUTER_ADMIN_ROLE`).
  - `pause` / `unpause`: Controls deposit/withdrawal operations.

### Vault.sol
- **Purpose**: Manages fund storage and transfers, with upgradeability.
- **Key Functions**:
  - `initialize`: Sets up RoleManager, WalletRouter, and Timelock.
  - `handleDeposit` / `handleWithdrawal`: Processes deposits and withdrawals.
  - `addSupportedToken` / `removeSupportedToken`: Manages token support.
  - `proposeSetWalletRouter` / `setWalletRouter`: Updates WalletRouter.
  - `proposeRecoverFunds` / `recoverFunds`: Recovers funds.
  - `pause` / `unpause`: Controls vault operations.
  - `upgradeTo`: Upgrades the contract implementation.

### Timelock.sol
- **Purpose**: Enforces timelock delays for sensitive operations.
- **Key Functions**:
  - `proposeSetWalletRouter` / `executeSetWalletRouter`: Manages WalletRouter updates.
  - `proposeRecoverFunds` / `executeRecoverFunds`: Manages fund recovery.
  - `setTimelock`: Adjusts timelock delay.

### Interfaces
- **IRoleManager.sol**: Defines role management functions.
- **ITimelock.sol**: Defines timelock operations.
- **IVault.sol**: Defines vault operations.

## Setup and Deployment

### Prerequisites
- **Solidity Compiler**: `^0.8.0`
- **Dependencies**: OpenZeppelin Contracts and OpenZeppelin Contracts Upgradeable (version 4.9.3).
- **Tools**: Foundry (`forge` and `cast`) for compilation, testing, and deployment.
- **Ethereum Network**: Deployable on Ethereum mainnet or testnets (e.g., Sepolia).

### Installation
1. Install Foundry:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```
2. Clone the repository:
   ```bash
   git clone https://github.com/Avitus-Labs/portal-wallet-contracts.git
   cd portal-wallet-contracts
   ```
3. Install dependencies:
   ```bash
   forge install OpenZeppelin/openzeppelin-contracts@v4.9.3
   forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.9.3
   ```
   Ensure `foundry.toml` includes:
   ```toml
   [profile.default]
   src = 'contracts'
   out = 'out'
   libs = ['lib']
   ```

### Deployment
The `DeployScript.s.sol` in `script/` deploys the contracts using Foundry. It:
- Deploys `RoleManager` with a multi-sig admin address.
- Deploys `Timelock` with the `RoleManager` address.
- Deploys `WalletRouter` with `RoleManager` and `Timelock` addresses.
- Deploys `Vault` as a UUPS proxy and initializes it.
- Sets the vault address in `WalletRouter`.

To deploy (e.g., on Sepolia):
1. Set up environment variables:
   ```bash
   export PRIVATE_KEY=your_private_key
   export RPC_URL=https://sepolia.infura.io/v3/your_infura_key
   ```
2. Run the deployment script:
   ```bash
   forge script script/DeployScript.s.sol --rpc-url $RPC_URL --broadcast --verify
   ```
   Note: Replace `your_private_key` and `your_infura_key` with your actual private key and RPC endpoint. Update `multiSigAdmin` in `DeployScript.s.sol` to a production multi-sig wallet address.

### Deployment Notes
- The `Vault` is deployed as a UUPS proxy using OpenZeppelin's `ERC1967Proxy`.

## Testing

The `VaultSystemTest.t.sol` in `test/` provides comprehensive tests for the vault system, including:
- Vault initialization and role setup.
- ETH and ERC20 deposit/withdrawal flows.
- Token support addition/removal.
- Fund recovery with timelock.
- Access control enforcement.
- Timelock operations.
- Pause functionality.
- Invalid input handling.
- Admin role transfer.
- Contract upgrade authorization.

### Running Tests
1. Compile contracts:
   ```bash
   forge build
   ```
2. Run tests:
   ```bash
   forge test -vvv
   ```
   Use `-vvv` for detailed output. To run a specific test:
   ```bash
   forge test --match-test testETHDepositAndWithdrawal
   ```

### Test Setup
- Deploys `RoleManager`, `Timelock`, `WalletRouter`, and `Vault` (via proxy).
- Deploys a `MockERC20` token for testing ERC20 flows.
- Funds test accounts (`user1`, `user2`) with ETH and tokens.
- Grants necessary roles (`OPERATOR_ROLE`, `VAULT_ADMIN_ROLE`, `ROUTER_ADMIN_ROLE`) with timelock simulation.

### Example Test Output
```bash
Running 10 tests for test/VaultSystemTest.t.sol:VaultSystemTest
[PASS] testAddRemoveSupportedToken() (gas: 123456)
[PASS] testAdminTransfer() (gas: 234567)
[PASS] testETHDepositAndWithdrawal() (gas: 345678)
[PASS] testERC20DepositAndWithdrawal() (gas: 456789)
[PASS] testInvalidInputs() (gas: 567890)
[PASS] testPauseFunctionality() (gas: 678901)
[PASS] testRecoverFunds() (gas: 789012)
[PASS] testTimelockOperations() (gas: 890123)
[PASS] testVaultAccessControl() (gas: 901234)
[PASS] testUpgradeAuthorization() (gas: 123456)
Suite result: ok. 10 passed; 0 failed; finished in 1.23ms
```

## Usage

1. **Depositing Funds**:
   - Call `WalletRouter.deposit(token, amount)` with ETH (`msg.value`) or ERC20 tokens (approve `WalletRouter` first).
   - Verify token support with `Vault.isSupportedToken(token)`.

2. **Withdrawing Funds**:
   - Use `WalletRouter.withdraw(recipient, token, amount)` with `OPERATOR_ROLE`.

3. **Managing Tokens**:
   - Add tokens with `Vault.addSupportedToken(token)` (requires `VAULT_ADMIN_ROLE`).
   - Remove tokens with `Vault.removeSupportedToken(token)` (requires no deposits).

4. **Role Management**:
   - Propose role changes with `RoleManager.proposeGrantRole` / `proposeRevokeRole`, execute after timelock.
   - Transfer admin role with `proposeAdminTransfer` / `acceptAdminTransfer`.

5. **Recovering Funds**:
   - Propose recovery with `Vault.proposeRecoverFunds(token, recipient, amount)`, execute after timelock.

6. **Upgrading Vault**:
   - Deploy a new `Vault` implementation and call `Vault.upgradeTo(newImplementation)` with `VAULT_ADMIN_ROLE`.

7. **Pausing Operations**:
   - Use `pause` / `unpause` on `RoleManager`, `WalletRouter`, or `Vault` with appropriate roles.

## Security Considerations

- **Timelock Delays**: 24-hour timelock for sensitive operations ensures monitoring and intervention.
- **Multi-Signature Admin**: Use a multi-sig wallet for `DEFAULT_ADMIN_ROLE` in production.[](https://github.com/monerium/smart-contracts)
- **Upgradeability**: UUPS proxy restricts upgrades to `VAULT_ADMIN_ROLE`.
- **Reentrancy Protection**: `ReentrancyGuard` prevents reentrancy attacks.
- **Token Safety**: `SafeERC20` ensures secure ERC20 interactions with balance checks.
- **Pausability**: Emergency pause halts operations during vulnerabilities.
- **Access Control**: Strict role checks prevent unauthorized actions.


## License

This project is licensed under the MIT License. See the SPDX-License-Identifier in each contract file.

