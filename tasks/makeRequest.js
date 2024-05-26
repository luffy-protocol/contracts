const fs = require("fs");
const path = require("path");
const {
  SecretsManager,
  ReturnType,
  decodeResult,
  SubscriptionManager,
  ResponseListener,
  FulfillmentCode,
} = require("@chainlink/functions-toolkit");
// const LuffyProtocolAbi = require("../build/artifacts/contracts/FunctionsTesting.sol/FunctionsTesting.json");
const LuffyProtocolAbi = require("../build/artifacts/contracts/LuffyProtocol.sol/LuffyProtocol.json");
const ethers = require("ethers");
const { networks } = require("../networks");
require("@chainlink/env-enc").config();

task(
  "make-request",
  "Makes a request to the Oracle function in the contract"
).setAction(async (taskArgs) => {
  const luffyProtocolAddress = "0x85028AE19BBDc6Beb9500AAbd598e3e75eA7983E"; // REPLACE this with your Functions consumer address
  const subscriptionId = 8378; // REPLACE this with your subscription ID
  const donId = "fun-avalanche-fuji-1";
  const routerAddress = "0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0";
  const gatewayUrls = [
    "https://01.functions-gateway.testnet.chain.link/",
    "https://02.functions-gateway.testnet.chain.link/",
  ];
  const secrets = {
    pinataKey: process.env.PINATA_API_KEY || "",
    mlsApiKey: process.env.MLS_API_KEY || "",
  };
  const slotIdNumber = 0; // slot ID where to upload the secrets
  const expirationTimeMinutes = 150; // expiration time in minutes of the secrets
  const explorerUrl = "https://testnet.snowtrace.io/";

  const gasLimit = 300000;

  // Initialize ethers signer and provider to interact with the contracts onchain
  const privateKey = process.env.PRIVATE_KEY; // fetch PRIVATE_KEY
  if (!privateKey)
    throw new Error(
      "private key not provided - check your environment variables"
    );

  const rpcUrl = networks.avalancheFuji.url; // fetch eth sepolia RPC URL

  if (!rpcUrl)
    throw new Error(`rpcUrl not provided  - check your environment variables`);

  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const wallet = new ethers.Wallet(privateKey);
  const signer = wallet.connect(provider); // create ethers signer for signing transactions

  //////// ESTIMATE REQUEST COSTS ////////

  console.log("\nEstimate request costs...");
  // Initialize and return SubscriptionManager
  const subscriptionManager = new SubscriptionManager({
    signer: signer,
    linkTokenAddress: networks.avalancheFuji.linkToken,
    functionsRouterAddress: routerAddress,
  });
  await subscriptionManager.initialize();

  // estimate costs in Juels

  const gasPriceWei = await signer.getGasPrice(); // get gasPrice in wei

  const estimatedCostInJuels =
    await subscriptionManager.estimateFunctionsRequestCost({
      donId: donId, // ID of the DON to which the Functions request will be sent
      subscriptionId: subscriptionId, // Subscription ID
      callbackGasLimit: gasLimit, // Total gas used by the consumer contract's callback
      gasPriceWei: BigInt(gasPriceWei), // Gas price in gWei
    });

  console.log(
    `Fulfillment cost estimated to ${ethers.utils.formatEther(
      estimatedCostInJuels
    )} LINK`
  );

  //////// MAKE REQUEST ////////

  console.log("\nMake request...");

  // First encrypt secrets and upload the encrypted secrets to the DON
  const secretsManager = new SecretsManager({
    signer: signer,
    functionsRouterAddress: routerAddress,
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

  const LuffyProtocol = new ethers.Contract(
    luffyProtocolAddress,
    LuffyProtocolAbi.abi,
    signer
  );

  const args = [
    "1150949",
    "https://orange-select-opossum-767.mypinata.cloud/ipfs/QmWbTKbiUoSmW4dKJLYoAT4a8AmRWFcrNYisGTET4o98AQ?pinataGatewayToken=71dx6yOphMuWQ_g-AnsHvIyaj168b316CK-yK31hd-3eHPdWpnWl01CbCiFJukXb",
  ];
  // Actual transaction call
  const transaction = await LuffyProtocol.triggerResult(
    args[0],
    args[1],
    slotIdNumber,
    donHostedSecretsVersion,
    []
  );

  // Log transaction details
  console.log(
    `\n✅ Functions request sent! Transaction hash ${transaction.hash}.`
  );

  console.log(
    `See your request in the explorer ${explorerUrl}/tx/${transaction.hash}`
  );

  console.log(`\nWaiting for the response...`);

  const responseListener = new ResponseListener({
    provider: provider,
    functionsRouterAddress: routerAddress,
  }); // Instantiate a ResponseListener object to wait for fulfillment.

  try {
    const response = await new Promise((resolve, reject) => {
      responseListener
        .listenForResponseFromTransaction(transaction.hash)
        .then((response) => {
          resolve(response); // Resolves once the request has been fulfilled.
        })
        .catch((error) => {
          reject(error); // Indicate that an error occurred while waiting for fulfillment.
        });
    });
    const fulfillmentCode = response.fulfillmentCode;

    if (fulfillmentCode === FulfillmentCode.FULFILLED) {
      console.log(
        `\n✅ Request ${
          response.requestId
        } successfully fulfilled. Cost is ${ethers.utils.formatEther(
          response.totalCostInJuels
        )} LINK.Complete reponse: `,
        response
      );
    } else if (fulfillmentCode === FulfillmentCode.USER_CALLBACK_ERROR) {
      console.log(
        `\n⚠️ Request ${
          response.requestId
        } fulfilled. However, the consumer contract callback failed. Cost is ${ethers.utils.formatEther(
          response.totalCostInJuels
        )} LINK.Complete reponse: `,
        response
      );
    } else {
      console.log(
        `\n❌ Request ${
          response.requestId
        } not fulfilled. Code: ${fulfillmentCode}. Cost is ${ethers.utils.formatEther(
          response.totalCostInJuels
        )} LINK.Complete reponse: `,
        response
      );
    }

    const errorString = response.errorString;
    if (errorString) {
      console.log(`\n❌ Error during the execution: `, errorString);
    } else {
      const responseBytesHexstring = response.responseBytesHexstring;
      if (ethers.utils.arrayify(responseBytesHexstring).length > 0) {
        const decodedResponse = decodeResult(
          response.responseBytesHexstring,
          ReturnType.bytes
        );
        console.log(
          `\n✅ Decoded response to ${ReturnType.bytes}: `,
          decodedResponse
        );
      }
    }
  } catch (error) {
    console.error("Error listening for response:", error);
  }
});
