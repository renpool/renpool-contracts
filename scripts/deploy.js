const {
    ethers: {
        BigNumber: { from: bn }
    },
    network: {
        config: {
            renTokenAddr,
            darknodeRegistryAddr,
            darknodePaymentAddr,
            claimRewardsAddr,
            gatewayAddr,
        }
    } } = require('hardhat');
const chalk = require('chalk');

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}

const DECIMALS = 18;
const DIGITS = bn(10).pow(DECIMALS);
const POOL_BOND = bn(100_000).mul(DIGITS);

async function main(print) {
    print(`${chalk.italic('\u{1F680} RenPool contract deployment')}`);
    print(`Using network ${chalk.bold(hre.network.name)} (${chalk.bold(hre.network.config.chainId)})`);

    print(`> Getting signers to deploy RenPool contract`);
    const [owner] = await ethers.getSigners();
    const nodeOperator = owner;

    print(`> Deploying ${chalk.bold('RenPool')} contract`);
    const RenPool = await ethers.getContractFactory('RenPool');
    const renPool = await RenPool.connect(nodeOperator).deploy(
        renTokenAddr,
        darknodeRegistryAddr,
        darknodePaymentAddr,
        claimRewardsAddr,
        gatewayAddr,
        owner.address,
        POOL_BOND);
    await renPool.deployed();

    print(`> Deployed to ${chalk.bold(renPool.address)} TX ${chalk.bold(renPool.deployTransaction.hash)}`);

    if (hre.network.name === 'hardhat') {
        print('> Skipping RenPool contract Etherscan verification')
    } else {
        print('> Waiting before verification');
        await sleep(30000);
        const balance = await renPool.balanceOf(owner.address);
        print(`  Owner's balance is ${chalk.yellow(balance)}`);

        print('> Verifying RenPool smart contract in Etherscan')

        await hre.run("verify:verify", {
            address: renPool.address,
            constructorArguments: [
                renTokenAddr,
                darknodeRegistryAddr,
                darknodePaymentAddr,
                claimRewardsAddr,
                gatewayAddr,
                owner.address,
                POOL_BOND
            ],
        });
    }

    return { renPool }
}

if (require.main === module) {
    main(console.log)
        .then(() => process.exit(0))
        .catch(err => {
            console.error(err);
            process.exit(1);
        });
} else {
    module.exports = function() {
        return main(function() {});
    }
}
