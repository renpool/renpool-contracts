const {
    ethers: {
        BigNumber: { from: bn }
    },
    network: {
        config: {
            accounts,
            renTokenAddr,
            topRenTokenHolderAddr,
            darknodeRegistryAddr,
            darknodePaymentAddr,
            claimRewardsAddr,
            gatewayRegistryAddr,
        },
        provider,
    } } = require('hardhat');
const RenToken = require('@renproject/sol/build/testnet/RenToken.json');
const chalk = require('chalk');

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}

const DECIMALS = 18;
const DIGITS = bn(10).pow(DECIMALS);
const POOL_BOND = bn(100_000).mul(DIGITS);

const print = console.log;

async function faucet(renToken, account) {
    await provider.request({ method: 'hardhat_impersonateAccount', params: [topRenTokenHolderAddr] });

    const holder = await ethers.getSigner(topRenTokenHolderAddr);
    const amount = POOL_BOND.mul(10);
    await renToken.connect(holder).transfer(account.address, amount);

    await provider.request({ method: 'hardhat_stopImpersonatingAccount', params: [topRenTokenHolderAddr] });
}

async function main() {
    print(`${chalk.italic('\u{1F680} RenPool contract deployment')}`);
    print(`Using network ${chalk.bold(hre.network.name)} (${chalk.bold(hre.network.config.chainId)})`);

    print(`Getting signers to deploy RenPool contract`);
    const owner = new ethers.Wallet(accounts[0], ethers.provider);
    const nodeOperator = owner;

    print(`Deploying ${chalk.bold('RenPool')} contract`);
    const RenPool = await ethers.getContractFactory('RenPool');
    const renPool = await RenPool.connect(nodeOperator).deploy(
        renTokenAddr,
        darknodeRegistryAddr,
        darknodePaymentAddr,
        claimRewardsAddr,
        gatewayRegistryAddr,
        owner.address,
        POOL_BOND);
    await renPool.deployed();

    print(`Deployed to ${chalk.bold(renPool.address)} TX ${chalk.bold(renPool.deployTransaction.hash)}`);

    if (hre.network.name === 'hardhat') {
        print('Skipping RenPool contract Etherscan verification')
    } else {
        print('Waiting before verification');
        await sleep(30000);
        const balance = await renPool.balanceOf(owner.address);
        print(`  Owner's balance is ${chalk.yellow(balance)}`);

        print('Verifying RenPool smart contract in Etherscan')

        await hre.run("verify:verify", {
            address: renPool.address,
            constructorArguments: [
                renTokenAddr,
                darknodeRegistryAddr,
                darknodePaymentAddr,
                claimRewardsAddr,
                gatewayRegistryAddr,
                owner.address,
                POOL_BOND
            ],
        });
    }

    const renToken = new ethers.Contract(renTokenAddr, RenToken.abi, owner);

    return { renPool, renToken, faucet };
}

if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch(err => {
            console.error(err);
            process.exit(1);
        });
} else {
    module.exports = function () {
        return main();
    }
}
