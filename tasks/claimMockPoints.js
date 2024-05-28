const path = require("path");

const LuffyProtocolAbi = require("../build/artifacts/contracts/LuffyProtocol.sol/LuffyProtocol.json");
const ethers = require("ethers");
const { networks } = require("../networks");
require("@chainlink/env-enc").config();

task("claim-mock-points", "Claims mock points in LuffyProtocol").setAction(
  async (taskArgs) => {
    const luffyProtocolAddress = "0x09249908F451EAe8fF4612e3E2C4a0f574a114f4"; // REPLACE this with your Functions consumer address

    // Initialize ethers signer and provider to interact with the contracts onchain
    const privateKey = process.env.PRIVATE_KEY; // fetch PRIVATE_KEY
    if (!privateKey)
      throw new Error(
        "private key not provided - check your environment variables"
      );

    const rpcUrl = networks.avalancheFuji.url; // fetch eth sepolia RPC URL

    if (!rpcUrl)
      throw new Error(
        `rpcUrl not provided  - check your environment variables`
      );

    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

    const wallet = new ethers.Wallet(privateKey);
    const signer = wallet.connect(provider); // create ethers signer for signing transactions

    const LuffyProtocol = new ethers.Contract(
      luffyProtocolAddress,
      LuffyProtocolAbi.abi,
      signer
    );
    const explorerUrl = "https://testnet.snowtrace.io";

    const args = [
      "1150949",
      "0x5A6B842891032d702517a4E52ec38eE561063539",
      [
        "0x0000000000000000000000000000000000000000000000000000000000000003",
        "0x0000000000000000000000000000000000000000000000000000000000000051",
        "0x0000000000000000000000000000000000000000000000000000000000000037",
        "0x0000000000000000000000000000000000000000000000000000000000000043",
        "0x0000000000000000000000000000000000000000000000000000000000000016",
        "0x0000000000000000000000000000000000000000000000000000000000000063",
        "0x000000000000000000000000000000000000000000000000000000000000002c",
        "0x0000000000000000000000000000000000000000000000000000000000000012",
        "0x0000000000000000000000000000000000000000000000000000000000000048",
        "0x0000000000000000000000000000000000000000000000000000000000000027",
        "0x000000000000000000000000000000000000000000000000000000000000003c",
      ],
      "127",
    ];
    // Actual transaction call
    const transaction = await LuffyProtocol.zclaimPointsTest(...args);

    // Log transaction details
    console.log(
      `\n✅ claim points request sent! Transaction hash ${transaction.hash}.`
    );

    console.log(
      `See your call in the explorer ${explorerUrl}/tx/${transaction.hash}`
    );
  }
);
