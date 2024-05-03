const { networks } = require("../../networks");
const fs = require("fs");

task("deploy-protocol", "Deploys the LuffyProtocol contract")
  .addOptionalParam(
    "verify",
    "Set to true to verify contract",
    false,
    types.boolean
  )
  .setAction(async (taskArgs) => {
    console.log(`Deploying LuffyProtocol contract to ${network.name}`);

    console.log("\n__Compiling Contracts__");
    await run("compile");

    const functionsRouter = "0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C"; // Chainlink Functions Router in Arbitrum Sepolia
    const sourceCode = fs.readFileSync("./oracle-script.js", "utf8"); // Source code of the Chainlink Functions
    const subcriptionId = "37"; // Chainlink Functions Subscription ID
    const donId =
      "0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000"; // Chainlink Functions Don ID for Arbitrum Sepolia

    const args = [functionsRouter, sourceCode, subcriptionId, donId];

    const protocolContractFactory = await ethers.getContractFactory(
      "LuffyProtocol"
    );
    const protocolContract = await protocolContractFactory.deploy(...args);

    console.log(
      `\nWaiting ${
        networks[network.name].confirmations
      } blocks for transaction ${
        protocolContract.deployTransaction.hash
      } to be confirmed...`
    );

    await protocolContract.deployTransaction.wait(
      networks[network.name].confirmations
    );

    console.log(
      "\nDeployed LuffyProtocol contract to:",
      protocolContract.address
    );

    if (network.name === "localFunctionsTestnet") {
      return;
    }

    const verifyContract = taskArgs.verify;
    if (
      network.name !== "localFunctionsTestnet" &&
      verifyContract &&
      !!networks[network.name].verifyApiKey &&
      networks[network.name].verifyApiKey !== "UNSET"
    ) {
      try {
        console.log("\nVerifying contract...");
        await run("verify:verify", {
          address: protocolContract.address,
          constructorArguments: args,
        });
        console.log("Contract verified");
      } catch (error) {
        if (!error.message.includes("Already Verified")) {
          console.log(
            "Error verifying contract.  Ensure you are waiting for enough confirmation blocks, delete the build folder and try again."
          );
          console.log(error);
        } else {
          console.log("Contract already verified");
        }
      }
    } else if (verifyContract && network.name !== "localFunctionsTestnet") {
      console.log(
        "\nPOLYGONSCAN_API_KEY, ETHERSCAN_API_KEY or FUJI_SNOWTRACE_API_KEY is missing. Skipping contract verification..."
      );
    }

    console.log(
      `\n LuffyProtocol contract deployed to ${protocolContract.address} on ${network.name}`
    );
  });
