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

    const args = [
      fs.readFileSync("./mls-oracle-script.js", "utf8"),
      networks.avalancheFuji.vrfWrapper,
      networks.avalancheFuji.ccipRouter,
      networks.avalancheFuji.usdcToken,
      networks.avalancheFuji.linkToken,
      [
        "58387336616451823836734822744286210528343491445611152550443089243189960990986",
        "42777266604767705378881328016196847279435767347742105064170763126637428887845",
      ],
      [
        networks.avalancheFuji.ethToUsdPriceFeed,
        networks.avalancheFuji.linkToUsdPriceFeed,
      ],
    ];

    const protocolContractFactory = await ethers.getContractFactory(
      "LuffyProtocol"
    );
    const protocolContract = await protocolContractFactory.deploy(args);

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
          constructorArguments: [args],
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
