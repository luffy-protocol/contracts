const { decodeResult, ReturnType } = require("@chainlink/functions-toolkit");
const { ethers } = require("ethers");

task("set-upkeep", "Decodes hex string to string").setAction(
  async (taskArgs) => {
    const data = ethers.utils.defaultAbiCoder.encode(
      ["uint256[2]"],
      [
        [
          "0",
          "16066178092839559643242633547994395404135478360281604153066220450532386632321",
        ],
      ]
    );

    const functionSelector = ethers.utils
      .id("setUpKeepIds(uint256[2])")
      .substring(0, 10);

    console.log("Data");
    console.log(functionSelector + data.slice(2));
  }
);
