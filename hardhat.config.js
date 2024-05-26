require("@nomicfoundation/hardhat-toolbox");
require("hardhat-dependency-compiler");
require("hardhat-contract-sizer");
require("./tasks");
const { networks } = require("./networks");

const REPORT_GAS =
  process.env.REPORT_GAS?.toLowerCase() === "true" ? true : false;

const SOLC_SETTINGS = {
  optimizer: {
    enabled: true,
    runs: 1_000,
  },
};
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.25",
        settings: SOLC_SETTINGS,
      },
      {
        version: "0.8.7",
        settings: SOLC_SETTINGS,
      },
    ],
  },

  networks: {
    ...networks,
  },
  etherscan: {
    apiKey: {
      sepolia: networks.ethereumSepolia.verifyApiKey,
      arbitrumSepolia: networks.arbitrumSepolia.verifyApiKey,
      avalancheFujiTestnet: networks.avalancheFuji.verifyApiKey,
      optimsimSepolia: networks.optimismSepolia.verifyApiKey,
      baseSepolia: networks.baseSepolia.verifyApiKey,
    },
    customChains: [
      {
        network: "arbitrumSepolia",
        chainId: networks.arbitrumSepolia.chainId,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/",
        },
      },
      {
        network: "optimsimSepolia",
        chainId: networks.optimismSepolia.chainId,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io/",
        },
      },
      {
        network: "baseSepolia",
        chainId: networks.baseSepolia.chainId,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org/",
        },
      },
    ],
  },
  gasReporter: {
    enabled: REPORT_GAS,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./build/cache",
    artifacts: "./build/artifacts",
  },
  mocha: {
    timeout: 200000,
  },
};
