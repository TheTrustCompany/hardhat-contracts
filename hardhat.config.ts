import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "hardhat-deploy";

const INFURA_API_KEY: string = vars.get("INFURA_API_KEY");
const ETHERSCAN_API_KEY: string = vars.get("ETHERSCAN_API_KEY");

const DEPLOYER_PRIVATE_KEY = vars.get("DEPLOYER_PRIVATE_KEY");
const USER_PRIVATE_KEY = vars.get("USER_PRIVATE_KEY");

const accounts = [DEPLOYER_PRIVATE_KEY, USER_PRIVATE_KEY];

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  namedAccounts: {
    deployer: 0,
    user: 1,
    relayer: 2,
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_API_KEY,
    },
  },
  networks: {
    sepolia: {
      accounts,
      chainId: 11155111,
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
    },
  },
  typechain: {
    outDir: "types",
    target: "ethers-v6",
  },
};

export default config;
