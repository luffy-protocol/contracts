const path = require("path");

const LuffyProtocolAbi = require("../build/artifacts/contracts/LuffyProtocol.sol/LuffyProtocol.json");
const ethers = require("ethers");
const { networks } = require("../networks");
require("@chainlink/env-enc").config();

task("run-automation", "Runs an automation request in the contract").setAction(
  async (taskArgs) => {
    const luffyProtocolAddress = "0x886b99Ee4B4130884f5c04AB6A934978F43bc364"; // REPLACE this with your Functions consumer address

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

    console.log("\nMake request...");

    const LuffyProtocol = new ethers.Contract(
      luffyProtocolAddress,
      LuffyProtocolAbi.abi,
      signer
    );

    const responseBytes =
      "0xfaa6bbe7b58babe1c273ac4074ffeb617513b2b55e5ae226c076f234c68066970000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a04d09e1d52e349aa1f7b61a88ad773fcd1e289b5b1e18bca7a5f97a1b743113ff0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000003b6261666b726569677a326e6a6a727668676f6c6c366c6b6e6668376a3761716b346d7064746d6871726874656c6d6e7a373633696d6a33687473710000000000";

    // Actual transaction call
    const transaction = await LuffyProtocol.performUpkeep(responseBytes);

    // Log transaction details
    console.log(
      `\n✅ Automation request sent! Transaction hash ${transaction.hash}.`
    );

    console.log(
      `See your request in the explorer ${explorerUrl}/tx/${transaction.hash}`
    );
  }
);
