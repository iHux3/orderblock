require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-web3");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: {
        version: "0.8.0",
        settings: {
            optimizer: {
                enabled: true,
                runs: 0
            }
        }
    },
    networks: {
        kovan: {
            url: `https://kovan.infura.io/v3/${process.env.INFURA_KEY}`,
            accounts: [`0x${process.env.DEPLOYER_PRIVATE_KEY}`]
        }
    }
};
