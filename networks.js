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
  avalancheFuji: {
    url: "https://api.avax-test.network/ext/bc/C/rpc",
    gasPrice: undefined,
    nonce: undefined,
    accounts,
    verifyApiKey: process.env.FUJI_SNOWTRACE_API_KEY || "UNSET",
    chainId: 43113,
    confirmations: DEFAULT_VERIFICATION_BLOCK_CONFIRMATIONS,
    nativeCurrencySymbol: "AVAX",
    vrfWrapper: "0x327B83F409E1D5f13985c6d0584420FA648f1F56",
    ccipRouter: "0xF694E193200268f9a4868e4Aa017A0118C9a8177",
    usdcToken: "0x5425890298aed601595a70AB815c96711a31Bc65",
    linkToken: "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846",
    ethToUsdPriceFeed: "0x5498BB86BC934c8D34FDA08E81D444153d0D06aD",
    linkToUsdPriceFeed: "0x34C4c526902d88a3Aa98DB8a9b802603EB1E3470",
    protocolAddress: "0xf97d85DF6c4D2b032645EE2C2D24423Ed66793f4",
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
    vrfWrapper: "0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1",
    ccipRouter: "0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59",
    usdcToken: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
    linkToken: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
    ethToUsdPriceFeed: "0x694AA1769357215DE4FAC081bf1f309aDC325306",
    linkToUsdPriceFeed: "0xc59E3633BAAC79493d908e63626716e204A45EdF",
    crosschainAddress: "0xCBe49DBE7bf83f8238b4Ae89c1c67Af17b48D526",
  },
  arbitrumSepolia: {
    url:
      "https://arb-sepolia.g.alchemy.com/v2/" +
      process.env.ALCHEMY_API_KEY_ARBITRUM,
    gasPrice: undefined,
    nonce: undefined,
    accounts,
    verifyApiKey: process.env.ARBISCAN_API_KEY || "UNSET",
    chainId: 421614,
    confirmations: DEFAULT_VERIFICATION_BLOCK_CONFIRMATIONS,
    nativeCurrencySymbol: "ETH",
    vrfWrapper: "0x29576aB8152A09b9DC634804e4aDE73dA1f3a3CC",
    ccipRouter: "0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165",
    usdcToken: "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d",
    linkToken: "0xb1D4538B4571d411F07960EF2838Ce337FE1E80E",
    ethToUsdPriceFeed: "0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165",
    linkToUsdPriceFeed: "0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298",
    crosschainAddress: "0xE54b2A824E59890183E9a6e50911aDee6A587a7B",
  },
  baseSepolia: {
    url:
      "https://base-sepolia.g.alchemy.com/v2/" +
      process.env.ALCHEMY_API_KEY_SEPOLIA,
    gasPrice: undefined,
    nonce: undefined,
    accounts,
    verifyApiKey: process.env.BASESCAN_API_KEY || "UNSET",
    chainId: 84532,
    confirmations: 3,
    nativeCurrencySymbol: "ETH",
    vrfWrapper: "0x0000000000000000000000000000000000000000",
    ccipRouter: "0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93",
    usdcToken: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
    linkToken: "0xE4aB69C077896252FAFBD49EFD26B5D171A32410",
    ethToUsdPriceFeed: "0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1",
    linkToUsdPriceFeed: "0xb113F5A928BCfF189C998ab20d753a47F9dE5A61",
    crosschainAddress: "0xB096d51062F906c4f72d394fe522C845c377370D",
  },

  optimismSepolia: {
    url:
      "https://opt-sepolia.g.alchemy.com/v2/" +
      process.env.ALCHEMY_API_KEY_OPTIMISM,
    gasPrice: undefined,
    nonce: undefined,
    accounts,
    verifyApiKey: process.env.OPTIMISTIC_API_KEY || "UNSET",
    chainId: 11155420,
    confirmations: DEFAULT_VERIFICATION_BLOCK_CONFIRMATIONS,
    nativeCurrencySymbol: "ETH",
    vrfWrapper: "0x0000000000000000000000000000000000000000",
    ccipRouter: "0x114A20A10b43D4115e5aeef7345a1A71d2a60C57",
    usdcToken: "0x5fd84259d66Cd46123540766Be93DFE6D43130D7",
    linkToken: "0xE4aB69C077896252FAFBD49EFD26B5D171A32410",
    ethToUsdPriceFeed: "0x61Ec26aA57019C486B10502285c5A3D4A4750AD7",
    linkToUsdPriceFeed: "0x53f91dA33120F44893CB896b12a83551DEDb31c6",
    crosschainAddress: "0x0C29b8C5121a4a72E9D623eFe418875fc7E3Dd15",
  },
};

module.exports = {
  networks,
};
