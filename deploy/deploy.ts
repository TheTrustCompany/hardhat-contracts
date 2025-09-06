import { ZeroAddress } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const AI_SIGNER = ZeroAddress; // replace with actual AI signer address
const CHALLENGE_SECONDS = 60; // 1 minute for testing, increase for production

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const deployedEscrowJudge = await deploy("EscrowJudge", {
    from: deployer,
    log: true,
    args: [AI_SIGNER, CHALLENGE_SECONDS],
  });

  console.log(`EscrowJudge contract: `, deployedEscrowJudge.address);
};
export default func;
func.id = "deploy_escrowJudge"; // id required to prevent reexecution
func.tags = ["EscrowJudge"];
