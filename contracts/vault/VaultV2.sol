// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "./Vault.sol";
// import "@openzeppelin-upgradeable/contracts/utils/AddressUpgradeable.sol";
// import "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

// contract VaultV2 is Vault {

//         using AddressUpgradeable for address payable;
//         using SafeERC20Upgradeable for IERC20Upgradeable;

//     /// @dev Disable initializers in the implementation contract
//     constructor() {
//         _disableInitializers();
//     }

//     // ============ NEW FEATURES ============

//     /// @notice Mapping to track individual user deposits
//     mapping(address => mapping(address => uint256)) public userDeposits;

//     /// @notice Emitted when a user's deposit balance changes
//     event UserDepositChanged(address indexed user, address indexed token, uint256 amount);

//     // ============ UPGRADE SAFETY ============

//     /// @notice Version identifier
//     function version() external pure virtual returns (string memory) {
//         return "Vault v2";
//     }

//     /// @notice Override authorization with additional checks
//     function _authorizeUpgrade(address newImplementation) 
//         internal 
//         onlyVaultAdmin 
//         override 
//     {
//         super._authorizeUpgrade(newImplementation); // Reuse parent checks
//         // Add any additional upgrade validation here
//     }

//     // ============ NEW FUNCTIONALITY ============

//     /// @notice Records individual user deposits (extends handleDeposit)
//         // In VaultV2.sol
//         function handleDeposit(
//             address user, 
//             address token, 
//             uint256 amount
//         ) external payable override onlyWalletRouter onlySupportedToken(token) whenNotPaused {
//             // Replicate parent logic
//             totalDeposits[token] += amount;
//             emit DepositProcessed(user, token, amount);
            
//             // Add V2 functionality
//             userDeposits[user][token] += amount;
//             emit UserDepositChanged(user, token, amount);
//         } 

//         function handleWithdrawal(
//             address recipient, 
//             address token, 
//             uint256 amount
//         ) external override onlyWalletRouter onlySupportedToken(token) whenNotPaused {
//             // Directly implement parent logic (safer for upgradeable contracts)
//             // require(totalDeposits[token] >= amount, "Insufficient balance");
            
//             if (token == address(0)) {
//                 payable(recipient).sendValue(amount);
//             } else {
//                 IERC20Upgradeable(token).safeTransfer(recipient, amount);
//             }
            
//             // totalDeposits[token] -= amount;
//             // emit WithdrawalProcessed(recipient, token, amount);
            
//             // // Add V2-specific logic
//             // userDeposits[recipient][token] -= amount;
//             // emit UserDepositChanged(recipient, token, userDeposits[recipient][token]);
//         }

//     /// @notice New function to get a user's deposit balance
//     function getUserDeposit(address user, address token) external view returns (uint256) {
//         return userDeposits[user][token];
//     }
// }