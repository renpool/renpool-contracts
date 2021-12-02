require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");

const path = require('path');

task('dev', 'Starts a JSON-RPC server on top of Hardhat Network after compiling the project and running a user-defined script')
  .addPositionalParam("script", "A js file to be run within Hardhat's environment")
  .setAction(async ({ script }, hre) => {
    hre.dev = { script };
    await hre.run("node", { message: "Hello, World!" });
  });

subtask('node:server-ready')
  .setAction(async (taskArgs, hre, runSuper) => {
    await runSuper(taskArgs);

    if (hre.dev !== undefined) {
      const script = hre.dev.script;
      console.log(`Running script '${script}'`);

      const scriptPath = path.resolve(script, ".");
      require(scriptPath);
    }

  });

const deployments = require('./ren-deployments.js');

const FORK = process.env.FORK !== undefined ? process.env.FORK : 'kovan';

const networks = {
  mainnet: {
    chainId: 1,
    url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
    forking: {
      blockNumber: 13611808,
    },
    build: 'mainnet',
    contracts: {
      ...deployments.mainnet,
    },
  },
  kovan: {
    chainId: 42,
    url: `https://eth-kovan.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
    forking: {
      blockNumber: 28381671,
    },
    build: 'testnet',
    contracts: {
      ...deployments.kovan,
    },
  }
};

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.7",
  networks: {
    hardhat: {
      forking: {
        url: networks[FORK].url,
        blockNumber: networks[FORK].forking.blockNumber,
      },
      chainId: networks[FORK].chainId,
      build: networks[FORK].build,
      ...networks[FORK].contracts,
    },
    kovan: {
      chainId: networks.kovan.chainId,
      url: networks.kovan.url,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      ...networks.kovan.contracts,
    },
  },
  mocha: {
    timeout: 60000
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
