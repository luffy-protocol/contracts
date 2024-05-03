const { networks } = require("../../networks");
const fs = require("fs");
task("deploy-oracle", "Deploys the ZkCricketOracle contract")
  .addOptionalParam(
    "verify",
    "Set to true to verify contract",
    false,
    types.boolean
  )
  .setAction(async (taskArgs) => {
    console.log(`Deploying ZkCricketOracle contract to ${network.name}`);

    console.log("\n__Compiling Contracts__");
    await run("compile");

    const args = [
      "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0",
      "534351",
      "0x" + "09f1af4e16728fcf340051055159f0f9d5e00b54".padStart(64, "0"),
      "0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766",
      fs.readFileSync("./oracle-script.js", "utf8"),
      "2435",
      "0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000",
    ];

    const protocolContractFactory = await ethers.getContractFactory(
      "ZkCricketOracle"
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
      "\nDeployed ZkCricketOracle contract to:",
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
      `\n ZkCricketOracle contract deployed to ${protocolContract.address} on ${network.name}`
    );
  });
