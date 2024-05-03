const { decodeResult, ReturnType } = require("@chainlink/functions-toolkit");
const { ethers } = require("ethers");

task("decode-result", "Decodes hex string to string").setAction(
  async (taskArgs) => {
    const destinationAddress =
      "0x" + "497f5b0ae3873604ac303582b13b66d14d520e7b".padStart(64, "0");

    const data = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "bytes32", "string"],
      [
        91515,
        "0x1c0ccbbe6033f7c3ea7fc31fc1be185a4d66d235ef51fb3b46c01a7e98ea65f1",
        "https://amethyst-impossible-ptarmigan-368.mypinata.cloud/ipfs/bafkreihafgg2mtsrbnldql2t37k5pkw6pamcuzv4zmcocmkscoksupg2me?pinataGatewayToken=CUMCxB7dqGB8wEEQqGSGd9u1edmJpWmR9b0Oiuewyt5gs633nKmTogRoKZMrG4Vk",
      ]
    );
    const hexString =
      "0x45786563204572726F723A2073796E746178206572726F722C2052414D2065786365656465642C206F72206F74686572206572726F72";
    const decodedResponse = decodeResult(hexString, ReturnType.string);
    console.log(decodedResponse);

    console.log("Destination Address");
    console.log(destinationAddress);
    console.log("Data");
    console.log(data);
  }
);
