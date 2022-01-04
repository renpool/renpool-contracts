const {
    ethers: {
        BigNumber: { from: bn }
    },
    network: {
        config: {
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
    print(`Given ${chalk.bold(amount)} REN to (${chalk.bold(account.address)})`);

    await provider.request({ method: 'hardhat_stopImpersonatingAccount', params: [topRenTokenHolderAddr] });
}

async function main() {
    print(`${chalk.italic('\u{1F680} RenPoolFactory contract deployment')}`);
    print(`Using network ${chalk.bold(hre.network.name)} (${chalk.bold(hre.network.config.chainId)})`);

    print(`Getting signers to deploy RenPoolFactory contract`);
    const [owner] = await ethers.getSigners();
    // const nodeOperator = owner;

    print(`Deploying ${chalk.bold('RenPoolFactory')} contract`);
    const RenPoolFactory = await ethers.getContractFactory('RenPoolFactory');
    const renPoolFactory = await RenPoolFactory.connect(owner).deploy();
    await renPoolFactory.deployed();
    // const renPool = await RenPoolFactory.connect(nodeOperator).deploy(
    //     renTokenAddr,
    //     darknodeRegistryAddr,
    //     darknodePaymentAddr,
    //     claimRewardsAddr,
    //     gatewayRegistryAddr,
    //     owner.address,
    //     nodeOperator.address,
    //     POOL_BOND);
    // await renPool.deployed();

    print(`Deployed to ${chalk.bold(renPoolFactory.address)} TX ${chalk.bold(renPoolFactory.deployTransaction.hash)}`);

    const renToken = new ethers.Contract(renTokenAddr, RenToken.abi, owner);

    if (hre.network.name === 'hardhat') {
        print('Skipping RenPoolFactory contract Etherscan verification')

        await provider.request({ method: 'hardhat_impersonateAccount', params: [topRenTokenHolderAddr] });

        print('Giving REN tokens to Hardhat signers');

        const signer = await ethers.getSigner(topRenTokenHolderAddr);

        for (const user of await ethers.getSigners()) {
            const amount = POOL_BOND.mul(5);
            await renToken.connect(signer).transfer(user.address, amount);
            print(`Given ${amount} REN to ${user.address}`);
        }

        await provider.request({ method: 'hardhat_stopImpersonatingAccount', params: [topRenTokenHolderAddr] });

        print('Setting up mining options');

        await provider.send("evm_setAutomine", [false]);
        await provider.send("evm_setIntervalMining", [5000]);
    } else {
        print('Waiting before verification');
        await sleep(30000);
        // const balance = await renPool.balanceOf(owner.address);
        // print(`  Owner's balance is ${chalk.yellow(balance)}`);

        print('Verifying RenPoolFactory smart contract in Etherscan')

        await hre.run("verify:verify", {
            address: renPoolFactory.address,
            constructorArguments: []
            //     renTokenAddr,
            //     darknodeRegistryAddr,
            //     darknodePaymentAddr,
            //     claimRewardsAddr,
            //     gatewayRegistryAddr,
            //     owner.address,
            //     POOL_BOND
            // ],
        });
    }

    return { renPoolFactory, renToken, faucet };
}

if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch(err => {
            console.error(err);
            process.exit(1);
        });
} else {
    main().then(p => {
        module.exports = p;
    })
}
