const { ethers, upgrades } = require("hardhat");

async function main() {
  // Configuration: Replace with your Arbitrum multi-sig admin address (e.g., Gnosis Safe)
  const MULTI_SIG_ADMIN = "0xYourMultiSigAdminAddressHere"; // Replace with actual address

  // Get signers
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Deploy RoleManager
  console.log("Deploying RoleManager...");
  const RoleManager = await ethers.getContractFactory("RoleManager");
  const roleManager = await RoleManager.deploy(MULTI_SIG_ADMIN);
  await roleManager.deployed();
  console.log("RoleManager deployed to:", roleManager.address);

  // Deploy Timelock
  console.log("Deploying Timelock...");
  const Timelock = await ethers.getContractFactory("Timelock");
  const timelock = await Timelock.deploy(roleManager.address);
  await timelock.deployed();
  console.log("Timelock deployed to:", timelock.address);

  // Deploy Vault (UUPS proxy)
  console.log("Deploying Vault (UUPS proxy)...");
  const Vault = await ethers.getContractFactory("Vault");
  const vault = await upgrades.deployProxy(
    Vault,
    [roleManager.address, ethers.constants.AddressZero, timelock.address],
    { initializer: "initialize", kind: "uups" }
  );
  await vault.deployed();
  console.log("Vault proxy deployed to:", vault.address);
  console.log("Vault implementation deployed to:", await upgrades.erc1967.getImplementationAddress(vault.address));

  // Deploy WalletRouter
  console.log("Deploying WalletRouter...");
  const WalletRouter = await ethers.getContractFactory("WalletRouter");
  const walletRouter = await WalletRouter.deploy(roleManager.address, timelock.address);
  await walletRouter.deployed();
  console.log("WalletRouter deployed to:", walletRouter.address);

  // Set WalletRouter in Vault (via timelock proposal)
  console.log("Proposing to set WalletRouter in Vault...");
  const vaultAdminRole = await roleManager.VAULT_ADMIN_ROLE();
  await roleManager.connect(deployer).grantRole(vaultAdminRole, deployer.address); // Temporarily grant role for testing
  const setWalletRouterKey = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("SET_WALLETROUTER"));
  await vault.proposeSetWalletRouter(walletRouter.address);
  console.log("Set WalletRouter proposed.");

  // Simulate timelock execution (in production, wait for MIN_TIMELOCK_DELAY)
  console.log("Executing set WalletRouter in Vault...");
  await ethers.provider.send("evm_increaseTime", [24 * 60 * 60 + 1]); // Increase time by 24 hours + 1 second
  await ethers.provider.send("evm_mine", []);
  const actionId = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "address", "uint256"],
      [setWalletRouterKey, walletRouter.address, (await ethers.provider.getBlock("latest")).timestamp - (24 * 60 * 60)]
    )
  );
  await vault.setWalletRouter(walletRouter.address, actionId);
  console.log("WalletRouter set in Vault.");

  // Set Vault in WalletRouter (via timelock proposal)
  console.log("Proposing to set Vault in WalletRouter...");
  const routerAdminRole = await roleManager.ROUTER_ADMIN_ROLE();
  await roleManager.connect(deployer).grantRole(routerAdminRole, deployer.address); // Temporarily grant role for testing
  const setVaultKey = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("SET_VAULT"));
  await walletRouter.proposeSetVault(vault.address);
  console.log("Set Vault proposed.");

  // Simulate timelock execution (in production, wait for MIN_TIMELOCK_DELAY)
  console.log("Executing set Vault in WalletRouter...");
  await ethers.provider.send("evm_increaseTime", [24 * 60 * 60 + 1]); // Increase time by 24 hours + 1 second
  await ethers.provider.send("evm_mine", []);
  const vaultActionId = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "address", "uint256"],
      [setVaultKey, vault.address, (await ethers.provider.getBlock("latest")).timestamp - (24 * 60 * 60)]
    )
  );
  await walletRouter.setVault(vault.address, vaultActionId);
  console.log("Vault set in WalletRouter.");

  console.log("Deployment completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });