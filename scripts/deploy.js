const { ethers } = require("hardhat");
async function main() {
  const C = await ethers.getContractFactory("DefiDexInterface");
  const c = await C.deploy();
  await c.waitForDeployment();
  console.log("DefiDexInterface deployed to:", await c.getAddress());
}
main().catch(e => { console.error(e); process.exitCode = 1; });
