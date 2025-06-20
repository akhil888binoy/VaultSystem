// SPDX-License-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVault {
    function initialize(
        address _roleManager,
        address _initialAdmin,
        address _walletRouter
    ) external;
    
    function handleDeposit(address user, address token, uint256 amount) external payable;
    function handleWithdrawal(address recipient, address token, uint256 amount) external;
    function totalDeposits(address token) external view returns (uint256);
    function supportedTokens(address token) external view returns (bool);
    function isSupportedToken(address token) external view returns (bool);
    
    function upgradeTo(address newImplementation) external;
    function addSupportedToken(address token) external;
    function removeSupportedToken(address token) external;
}