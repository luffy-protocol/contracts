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

    const ccipRouter = "0xF694E193200268f9a4868e4Aa017A0118C9a8177";
    const functionsRouter = "0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0"; // Chainlink Functions Router in Avalanche Fuji
    const sourceCode = fs.readFileSync("./mls-oracle-script.js", "utf8"); // Source code of the Chainlink Functions
    const subcriptionId = "37"; // Chainlink Functions Subscription ID
    const donId =
      "0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000"; // Chainlink Functions Don ID for Avalanche Fuji
    const automationRegistry = "0x819B58A646CDd8289275A87653a2aA4902b14fe6";
    const priceFeeds = [
      "0x5498BB86BC934c8D34FDA08E81D444153d0D06aD",
      "0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad",
      "0x34C4c526902d88a3Aa98DB8a9b802603EB1E3470",
    ];
    const args = [
      ccipRouter,
      functionsRouter,
      sourceCode,
      subcriptionId,
      donId,
      automationRegistry,
      priceFeeds,
    ];

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
