const { networks } = require("../../networks");
const fs = require("fs");

task("deploy-crosschain", "Deploys the LuffyCrosschain contract")
  .addOptionalParam(
    "verify",
    "Set to true to verify contract",
    false,
    types.boolean
  )
  .setAction(async (taskArgs) => {
    console.log(`Deploying LuffyCrosschain contract to ${network.name}`);

    console.log("\n__Compiling Contracts__");
    await run("compile");

    const crosschainContractFactory = await ethers.getContractFactory(
      "LuffyCrosschain"
    );

    const args = [
      networks.avalancheFuji.protocolAddress,
      networks[network.name].vrfWrapper,
      networks[network.name].ccipRouter,
      networks[network.name].usdcToken,
      networks[network.name].linkToken,
      [
        networks[network.name].ethToUsdPriceFeed,
        networks[network.name].linkToUsdPriceFeed,
      ],
    ];
    console.log(args);
    const crosschainContract = await crosschainContractFactory.deploy(...args);

    console.log(
      `\nWaiting ${
        networks[network.name].confirmations
      } blocks for transaction ${
        crosschainContract.deployTransaction.hash
      } to be confirmed...`
    );

    await crosschainContract.deployTransaction.wait(
      networks[network.name].confirmations
    );

    console.log(
      "\nDeployed LuffyCrosschain contract to:",
      crosschainContract.address
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
          address: crosschainContract.address,
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
      `\n LuffyCrosschain contract deployed to ${crosschainContract.address} on ${network.name}`
    );
  });
