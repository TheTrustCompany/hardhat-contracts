import { task, types } from "hardhat/config";

task("openCase", "Open a case in the CaseRegistry contract")
  .addOptionalParam("provider", "The provider's address")
  .addOptionalParam("deadline", "The delivery deadline as a unix timestamp", 0, types.int)
  .addOptionalParam("initialevidences", "Initial evidence CID(s) as a comma-separated string")
  .setAction(async ({ provider, deadline, initialevidences }, hre) => {
    const initialEvidencesArray = initialevidences ? initialevidences.split(",") : [];
    const [_, client, providerSigner] = await hre.ethers.getSigners();
    const caseRegistryAddress = (await hre.deployments.get("CaseRegistry")).address;
    const caseRegistry = await hre.ethers.getContractAt("CaseRegistry", caseRegistryAddress, client);

    const tx = await caseRegistry.openCase(provider || providerSigner.address, deadline, initialEvidencesArray, {
      value: hre.ethers.parseEther("0.01"),
    });
    const receipt = await tx.wait();
    if (!receipt || receipt.status === 0) {
      throw new Error("Transaction failed");
    }
    console.log("Tx hash receipt:", receipt.hash);
  });
