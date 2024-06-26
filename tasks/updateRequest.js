const fs = require("fs");
const path = require("path");
const {
  SecretsManager,
  simulateScript,
  buildRequestCBOR,
  ReturnType,
  decodeResult,
  Location,
  CodeLanguage,
} = require("@chainlink/functions-toolkit");
const LuffyAbi = require("../build/artifacts/contracts/LuffyProtocol.sol/LuffyProtocol.json");
const ethers = require("ethers");
const { networks } = require("../networks");
require("@chainlink/env-enc").config();

task("update-request", "Updates the Oracle function in the contract").setAction(
  async (taskArgs) => {
    const luffyAddress = "0xDc59057716677afE37755e8aA256c8d852D62f64"; // REPLACE this with your Functions consumer address
    const subscriptionId = 37; // REPLACE this with your subscription ID

    const functionsRouterAddress = "0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C";
    const donId = "fun-arbitrum-sepolia-1";
    const gatewayUrls = [
      "https://01.functions-gateway.testnet.chain.link/",
      "https://02.functions-gateway.testnet.chain.link/",
    ];
    const explorerUrl = "https://sepolia.arbiscan.io";
    // Initialize functions settings
    const source = fs
      .readFileSync(path.resolve(__dirname, "oracle-script.js"))
      .toString();

    const args = [
      "91515",
      "https://amethyst-impossible-ptarmigan-368.mypinata.cloud/ipfs/Qmb1ZQWyzZCHSpH4rVn5XCYtbRCemxn3Ed6K659XvmN4B3?pinataGatewayToken=CUMCxB7dqGB8wEEQqGSGd9u1edmJpWmR9b0Oiuewyt5gs633nKmTogRoKZMrG4Vk",
    ];
    const secrets = {
      pinataKey: process.env.PINATA_API_KEY || "",
      cricBuzzKey: process.env.CRICKET_API_KEY || "",
    };
    const slotIdNumber = 0; // slot ID where to upload the secrets
    const expirationTimeMinutes = 150; // expiration time in minutes of the secrets
    const gasLimit = 300000;

    // Initialize ethers signer and provider to interact with the contracts onchain
    const privateKey = process.env.PRIVATE_KEY; // fetch PRIVATE_KEY
    if (!privateKey)
      throw new Error(
        "private key not provided - check your environment variables"
      );

    const rpcUrl = networks.arbitrumSepolia.url; // fetch mumbai RPC URL

    if (!rpcUrl)
      throw new Error(
        `rpcUrl not provided  - check your environment variables`
      );

    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

    const wallet = new ethers.Wallet(privateKey);
    const signer = wallet.connect(provider); // create ethers signer for signing transactions

    //////// MAKE REQUEST ////////

    console.log("\nMake request...");

    // First encrypt secrets and upload the encrypted secrets to the DON
    const secretsManager = new SecretsManager({
      signer: signer,
      functionsRouterAddress: functionsRouterAddress,
      donId: donId,
    });
    await secretsManager.initialize();

    // Encrypt secrets and upload to DON
    const encryptedSecretsObj = await secretsManager.encryptSecrets(secrets);

    console.log(
      `Upload encrypted secret to gateways ${gatewayUrls}. slotId ${slotIdNumber}. Expiration in minutes: ${expirationTimeMinutes}`
    );
    // Upload secrets
    const uploadResult = await secretsManager.uploadEncryptedSecretsToDON({
      encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
      gatewayUrls: gatewayUrls,
      slotId: slotIdNumber,
      minutesUntilExpiration: expirationTimeMinutes,
    });

    if (!uploadResult.success)
      throw new Error(`Encrypted secrets not uploaded to ${gatewayUrls}`);

    console.log(
      `\n✅ Secrets uploaded properly to gateways ${gatewayUrls}! Gateways response: `,
      uploadResult
    );

    const donHostedSecretsVersion = parseInt(uploadResult.version); // fetch the version of the encrypted secrets
    const donHostedEncryptedSecretsReference =
      secretsManager.buildDONHostedEncryptedSecretsReference({
        slotId: slotIdNumber,
        version: donHostedSecretsVersion,
      }); // encode encrypted secrets version

    const automatedFunctionsConsumer = new ethers.Contract(
      luffyAddress,
      LuffyAbi.abi,
      signer
    );

    // Encode request
    const functionsRequestBytesHexString = buildRequestCBOR({
      codeLocation: Location.Inline, // Location of the source code - Only Inline is supported at the moment
      codeLanguage: CodeLanguage.JavaScript, // Code language - Only JavaScript is supported at the moment
      secretsLocation: Location.DONHosted, // Location of the encrypted secrets - DONHosted in this example
      source: source, // soure code
      encryptedSecretsReference: donHostedEncryptedSecretsReference,
      args: args,
      bytesArgs: [], // bytesArgs - arguments can be encoded off-chain to bytes.
    });

    console.log("FINAL LOGGING");
    console.log({
      functionsRequestBytesHexString,
      subscriptionId,
      gasLimit,
      donId: ethers.utils.formatBytes32String(donId),
    });

    // Update request settings
    const transaction = await automatedFunctionsConsumer.updateRequest(
      functionsRequestBytesHexString,
      subscriptionId,
      gasLimit,
      ethers.utils.formatBytes32String(donId) // jobId is bytes32 representation of donId
    );

    // Log transaction details
    console.log(
      `\n✅ Automated Functions request settings updated! Transaction hash ${transaction.hash} - Check the explorer ${explorerUrl}/tx/${transaction.hash}`
    );
  }
);
