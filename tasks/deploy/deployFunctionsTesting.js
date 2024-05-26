const { networks } = require("../../networks");
const fs = require("fs");

task("deploy-testing", "Deploys the FunctionsTesting contract")
  .addOptionalParam(
    "verify",
    "Set to true to verify contract",
    false,
    types.boolean
  )
  .setAction(async (taskArgs) => {
    console.log(`Deploying FunctionsTesting contract to ${network.name}`);

    console.log("\n__Compiling Contracts__");
    await run("compile");

    const testingContractFactory = await ethers.getContractFactory(
      "FunctionsTesting"
    );

    const args = [
      "0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0",
      fs.readFileSync("./mls-oracle-script.js", "utf8"),
      8378,
      "0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000",
    ];
    console.log(args);
    const testingContract = await testingContractFactory.deploy(...args);

    console.log(
      `\nWaiting ${
        networks[network.name].confirmations
      } blocks for transaction ${
        testingContract.deployTransaction.hash
      } to be confirmed...`
    );

    await testingContract.deployTransaction.wait(
      networks[network.name].confirmations
    );

    console.log(
      "\nDeployed FunctionsTesting contract to:",
      testingContract.address
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
          address: testingContract.address,
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
      `\n FunctionsTesting contract deployed to ${testingContract.address} on ${network.name}`
    );
  });
