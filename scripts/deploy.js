
const { ethers, upgrades } = require("hardhat");

async function main() {
  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Deployer balance:", (await deployer.getBalance()).toString());

  // Deploy RoleManager
  console.log("Deploying RoleManager...");
  const RoleManager = await ethers.getContractFactory("RoleManager");
  const roleManager = await RoleManager.deploy(deployer.address);
  await roleManager.deployed();
  console.log("RoleManager deployed to:", roleManager.address);

  // Deploy WalletRouter
  console.log("Deploying WalletRouter...");
  const WalletRouter = await ethers.getContractFactory("WalletRouter");
  const walletRouter = await WalletRouter.deploy(roleManager.address);
  await walletRouter.deployed();
  console.log("WalletRouter deployed to:", walletRouter.address);

  // Deploy Vault as an upgradeable proxy
  console.log("Deploying Vault proxy...");
  const Vault = await ethers.getContractFactory("Vault");
  const vault = await upgrades.deployProxy(
    Vault,
    [roleManager.address, deployer.address, walletRouter.address],
    { initializer: "initialize", kind: "uups" }
  );
  await vault.deployed();
  console.log("Vault proxy deployed to:", vault.address);

  // Grant roles
  console.log("Configuring roles...");
  const DEFAULT_ADMIN_ROLE = await roleManager.DEFAULT_ADMIN_ROLE();
  const VAULT_ADMIN_ROLE = await roleManager.VAULT_ADMIN_ROLE();
  const ROUTER_ADMIN_ROLE = await roleManager.ROUTER_ADMIN_ROLE();
  const OPERATOR_ROLE = await roleManager.OPERATOR_ROLE();

  // Grant VAULT_ADMIN_ROLE to deployer
  await roleManager.grantRole(VAULT_ADMIN_ROLE, deployer.address);
  console.log("Granted VAULT_ADMIN_ROLE to:", deployer.address);

  // Grant ROUTER_ADMIN_ROLE to deployer
  await roleManager.grantRole(ROUTER_ADMIN_ROLE, deployer.address);
  console.log("Granted ROUTER_ADMIN_ROLE to:", deployer.address);

  // Grant OPERATOR_ROLE to an operator (use deployer for testing)
  await roleManager.grantRole(OPERATOR_ROLE, deployer.address);
  console.log("Granted OPERATOR_ROLE to:", deployer.address);

  // Set Vault in WalletRouter
  console.log("Setting Vault in WalletRouter...");
  await walletRouter.setVault(vault.address);
  console.log("Vault set in WalletRouter");

  // Add USDC as a supported token (use MockERC20 for testing, or real USDC address)
  const USDC_ADDRESS = "0x75faf114eafb1BDbe6bF7B8c1E63FCaB97506b6D"; // Arbitrum Sepolia USDC
  // For testing, deploy MockERC20
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const usdc = await MockERC20.deploy("USD Coin", "USDC", 6);
  await usdc.deployed();
  console.log("Mock USDC deployed to:", usdc.address);

  console.log("Adding USDC as supported token...");
  await vault.addSupportedToken(usdc.address); // Replace with USDC_ADDRESS for production
  console.log("USDC added as supported token");

  // Verify setup
  console.log("Verifying setup...");
  console.log("Vault supports ETH:", await vault.supportedTokens(ethers.constants.AddressZero));
  console.log("Vault supports USDC:", await vault.supportedTokens(usdc.address));
  console.log("WalletRouter vault:", await walletRouter.vault());
  console.log("Deployer has VAULT_ADMIN_ROLE:", await roleManager.hasRole(VAULT_ADMIN_ROLE, deployer.address));
  console.log("Deployer has ROUTER_ADMIN_ROLE:", await roleManager.hasRole(ROUTER_ADMIN_ROLE, deployer.address));
  console.log("Deployer has OPERATOR_ROLE:", await roleManager.hasRole(OPERATOR_ROLE, deployer.address));

  // Save deployment addresses for verification
  console.log("\nDeployment addresses:");
  console.log(`RoleManager: ${roleManager.address}`);
  console.log(`WalletRouter: ${walletRouter.address}`);
  console.log(`Vault Proxy: ${vault.address}`);
  console.log(`Mock USDC: ${usdc.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
