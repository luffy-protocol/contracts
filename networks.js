require("@chainlink/env-enc").config();

const DEFAULT_VERIFICATION_BLOCK_CONFIRMATIONS = 5;

const PRIVATE_KEY = process.env.PRIVATE_KEY;

const SECOND_PRIVATE_KEY = process.env.SECOND_PRIVATE_KEY;

const accounts = [];
if (PRIVATE_KEY) {
  accounts.push(PRIVATE_KEY);
}
if (SECOND_PRIVATE_KEY) {
  accounts.push(SECOND_PRIVATE_KEY);
}

const networks = {
  scrollSepolia: {
    url:
      `https://rpc.ankr.com/scroll_sepolia_testnet/${process.env.ANKR_RPC_KEY}` ||
      "UNSET",
    gasPrice: undefined,
    nonce: undefined,
    accounts,
    verifyApiKey: process.env.SCROLL_API_KEY,
    chainId: 534351,
    confirmations: DEFAULT_VERIFICATION_BLOCK_CONFIRMATIONS,
    nativeCurrencySymbol: "ETH",
  },
  ethereumSepolia: {
    url:
      "https://eth-sepolia.g.alchemy.com/v2/" +
      process.env.ALCHEMY_API_KEY_SEPOLIA,
    gasPrice: undefined,
    nonce: undefined,
    accounts,
    verifyApiKey: process.env.ETHERSCAN_API_KEY || "UNSET",
    chainId: 11155111,
    confirmations: 3,
    nativeCurrencySymbol: "ETH",
  },
};

module.exports = {
  networks,
};
