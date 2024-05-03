const fs = require("fs");
const path = require("path");
const {
  simulateScript,
  ReturnType,
  decodeResult,
} = require("@chainlink/functions-toolkit");
const ethers = require("ethers");
require("@chainlink/env-enc").config();

task("simulate", "Simulates the Oracle function").setAction(
  async (taskArgs) => {
    // Initialize functions settings
    const source = fs
      .readFileSync(path.resolve(__dirname, "oracle-script.js"))
      .toString();

    const args = [
      "91555",
      "https://amethyst-impossible-ptarmigan-368.mypinata.cloud/ipfs/QmWVRzjvq1mZubSHFxKDBHQVeaDBmjpvKZgW88xJLYHmrD?pinataGatewayToken=CUMCxB7dqGB8wEEQqGSGd9u1edmJpWmR9b0Oiuewyt5gs633nKmTogRoKZMrG4Vk",
    ];
    const secrets = {
      pinataKey: process.env.PINATA_API_KEY || "",
      cricBuzzKey: process.env.CRICKET_API_KEY || "",
    };

    // Initialize ethers signer and provider to interact with the contracts onchain
    const privateKey = process.env.PRIVATE_KEY; // fetch PRIVATE_KEY
    if (!privateKey)
      throw new Error(
        "private key not provided - check your environment variables"
      );

    const rpcUrl =
      "https://arb-sepolia.g.alchemy.com/v2/" +
      process.env.ALCHEMY_API_KEY_ARBITRUM; // fetch Sepolia RPC URL

    if (!rpcUrl)
      throw new Error(
        `rpcUrl not provided  - check your environment variables`
      );

    ///////// START SIMULATION ////////////

    console.log("Start simulation...");

    const response = await simulateScript({
      source: source,
      args: args,
      bytesArgs: [], // bytesArgs - arguments can be encoded off-chain to bytes.
      secrets: secrets,
    });

    console.log("Simulation result", response);
    const errorString = response.errorString;
    if (errorString) {
      console.log(`❌ Error during simulation: `, errorString);
    } else {
      const returnType = ReturnType.bytes;
      const responseBytesHexstring = response.responseBytesHexstring;
      if (ethers.utils.arrayify(responseBytesHexstring).length > 0) {
        const decodedResponse = decodeResult(
          response.responseBytesHexstring,
          returnType
        );
        console.log(`✅ Decoded response to ${returnType}: `, decodedResponse);
      }
    }
  }
);
