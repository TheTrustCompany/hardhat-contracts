import { task } from "hardhat/config";

task("createPolicy", "Create an insurance policy in the CaseRegistry contract")
  .addParam("name", "The name of the policy")
  .addParam("description", "The description of the policy")
  .setAction(async ({ name, description }, hre) => {
    const [deployer] = await hre.ethers.getSigners();
    const caseRegistryAddress = (await hre.deployments.get("CaseRegistry")).address;
    const caseRegistry = await hre.ethers.getContractAt("CaseRegistry", caseRegistryAddress, deployer);

    const tx = await caseRegistry.createPolicy(name, description);
    await tx.wait();
    console.log(`Policy created with ID: ${tx.hash}`);
  });
