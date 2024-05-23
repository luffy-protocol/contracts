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
      .readFileSync(path.resolve(__dirname, "mls-oracle-script.js"))
      .toString();

    const args = [
      "1150754",
      "https://orange-select-opossum-767.mypinata.cloud/ipfs/QmUSzXkfuXSjTweMKUeVsS5KcBdsDksEGZfATh3zrmL1yF?pinataGatewayToken=71dx6yOphMuWQ_g-AnsHvIyaj168b316CK-yK31hd-3eHPdWpnWl01CbCiFJukXb",
    ];
    const secrets = {
      pinataKey: process.env.PINATA_API_KEY || "",
      mlsApiKey: process.env.MLS_API_KEY || "",
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
