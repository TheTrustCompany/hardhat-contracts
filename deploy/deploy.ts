import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { sleep } from "../utils";

const AI_SIGNER = "0x9C4AdC3251C264e39A3559e761697D232Deb1dB0"; // replace with actual AI signer address
const CHALLENGE_SECONDS = 60; // 1 minute for testing, increase for production

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const deployedCaseRegistry = await deploy("CaseRegistry", {
    from: deployer,
    log: true,
    args: [AI_SIGNER, CHALLENGE_SECONDS],
  });

  console.log(`CaseRegistry contract: `, deployedCaseRegistry.address);

  const verificationArgs = {
    address: deployedCaseRegistry.address,
    contract: "contracts/CaseRegistry.sol:CaseRegistry",
    constructorArguments: [AI_SIGNER, CHALLENGE_SECONDS],
  };

  console.info("\nSubmitting verification request on Etherscan...");
  await sleep(30000); // wait for etherscan to index the contract
  await hre.run("verify:verify", verificationArgs);
};
export default func;
func.id = "deploy_caseRegistry"; // id required to prevent reexecution
func.tags = ["CaseRegistry"];
