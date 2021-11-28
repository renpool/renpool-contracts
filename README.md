# RenPool Project

## Bringing community pools to the REN ecosystem

### What is REN?

RenVM is a permissionless and decentralized virtual machine protocol.

> _A secure network of virtual computers that power interoperability for decentralized applications, enabling cross-chain lending, exchanges, collateralization & more._

This document assumes a high-level understanding of the RenVM protocol.
Check <https://github.com/renproject/ren/wiki/> to learn more about the inner workings of RenVM.
More information about Ren and the Ren project can be found in <https://renproject.io/renvm>.
Visit <https://github.com/renproject> to explore their repos.

In other words, RenVM is a network of nodes, called _darknodes_, that perform Secure Multiparty Computation (SMPC) over Shamir Secret Shares, to control ECDSA Private Keys securely, and hence custody funds for cross-chain bridging.

These _darknodes_ earn fees for every transaction they process.
In order to power a _darknode_, you need to stake a utility token provided by RenVM.
This is the **REN** token, an [`ERC20` Ethereum token](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/).
The amount you have to stake, known as _bond_, is `100,000 REN` (currently about `88,000 USD`).

### What is the RenPool?

The RenPool project allows users to participate in **REN** staking pools,
which are rewarded with a share of fees earned by the _Darknode_.

> **You can earn _Darknode_ rewards without having 100K REN nor operaing a _Darknode_**

### RenPool Features

RenPool allows any user to

- create a new pool by becoming the node operator of a new _Darknode_.
- deposit **REN**s into a pool and when it reaches 100K, the RenPool team will set up and manage a new _Darknode_.
- **[TODO]** request a withdraw of a running pool. When another staker wants to take your place, they transfer the staked **REN**s to you, and they become part of the pool. However, keep in mind that you will lose your rewards for that epoch. Instead the new staker will receive it.
- **[TODO]** automatically deregister a running node when more than 50% of the staked REN collectively requests to withdraw their share.

Moreover, the RenPool team will **never** be in possession of your **REN** tokens nor your rewards.

### **TODO**

- We need to audit the smart contracts
- What about slashing?
- Ethereum gas?
- Explain fees for owner and node operator and staker

### How RenPool works

At its core, RenPool is powered by smart contracts that dictates how the pool rewards are distributed among its users.

![RenPool Architecture](./RenPool-arch.drawio.svg)

There are three main actors when using a RenPool.

- Owner
- Node Operator
- Stakers

In turn, the RenPool uses Ren smart contracts
<https://renproject.github.io/ren-client-docs/contracts/>
to interact with the RenVM in a decentralized and permissionless manner.
Ren contract addresses are published

- for `mainnet`. <https://renproject.github.io/contracts-ts/#/mainnet>
- for `testnet`. <https://renproject.github.io/contracts-ts/#/testnet>

### RenPool states

The following picture shows different states the RenPool can be in.

![RenPool FSM](./RenPool-FSM.drawio.svg)

When _unlocked_, stakers can either `deposit` or `withdraw` **REN** tokens as they see fit.
However, when the pool collects the Ren Bond, currently 100K **REN** tokens, it becomes _locked_.
Once the pool is _locked_, the node operator can register a new darknode
<https://docs.renproject.io/darknodes/getting-started/digital-ocean-or-how-to-setup-a-darknode/mac-os-and-linux>.

> ***Please note that the REN tokens collected by the contract are never in possession of the node operator nor the owner.***

After the darknode has been registered,
it will start to earn fees.
The stakers can then withdraw their respective percentage of these fees.

### Claiming Rewards

![RenPool Claim Rewards Sequence](./RenPool-rewards.drawio.svg)

## Getting started

The RenPool project uses the _Yarn_ package manager and the _Hardhat_ [https://hardhat.org/getting-started/](https://hardhat.org/getting-started/) development environment for Ethereum.
We use [Alchemy](https://www.alchemy.com/) JSON-RPC provider to fork Ethereum networks.

You can skip to the next section if you have a working _Yarn_ installation.
If not, here is how to install it.

```sh
npm install -g yarn
```

### Install project

```sh
yarn install
```

### Create an `.env` file from `.env.template`

This file defines environment variables read by _Hardhat_.

```sh
cp .env.template .env
```

Add your [Alchemy Key](https://docs.alchemy.com/alchemy/introduction/getting-started) to the newly created `.env` file

```txt
ALCHEMY_KEY=<your Alchemy key here>
```

### Init the _Hardhat_ console

This will create a local Blockchain plus 10 local `accounts` loaded with ETH.

```sh
yarn hardhat console
```

### Deploy `RenPool` contract to the local network and mint an ERC20 token called REN

You will get a fresh instance every time you init the _Hardhat_ console.

```js
> const { renPool, renToken, faucet } = await require('./scripts/deploy.js')()
```

`RenPool` and `RenToken` are contracts objects, while `faucet` is a function used to mint the REN token.

### You can now interact with the `renPool` and `renToken` contracts

To interact with the contract you can use any of the signers provided by _Hardhat_.

First, get some REN tokens from the faucet

```js
> const [signer] = await ethers.getSigners()
> (await renToken.balanceOf(signer.address)).toString()
'0'
> await faucet(renToken, signer)
> (await renToken.balanceOf(signer.address)).toString()
'1000000000000000000000000'
```

Deposit REN tokens into the Ren Pool

```js
> (await renPool.totalPooled()).toString()
'0'
> await renToken.connect(signer).approve(renPool.address, 100)
> await renPool.connect(signer).deposit(100)
```

Verify that the Ren Pool balance has been increased

```js
> (await renPool.totalPooled()).toString()
'100'
```

Withdraw some REN tokens

```js
> await renPool.connect(signer).withdraw(5)
> (await renPool.totalPooled()).toString()
> 95
```

### Running tests (open a new terminal)

```bash
>> brownie test
```

## Manually deploy client app

[https://www.freecodecamp.org/news/how-to-deploy-a-react-application-to-netlify-363b8a98a985/](https://www.freecodecamp.org/news/how-to-deploy-a-react-application-to-netlify-363b8a98a985/)

Install Netlify CLI: `npm install netlify-cli -g`.

```bash
>> yarn run setEnv:<TARGET_NETWORK>
>> yarn run deploy
```

The app is deployed to [https://renpool.netlify.app/](https://renpool.netlify.app/)

## Deploy smart contract

1. Get a funded wallet for the target network
2. Set .env file pointing to the target network
3. run brownie console
4. renToken, renPool = run('deploy')

[https://www.quicknode.com/guides/vyper/how-to-write-an-ethereum-smart-contract-using-vyper](https://www.quicknode.com/guides/vyper/how-to-write-an-ethereum-smart-contract-using-vyper)

## Setup and deploy to test networks

1. [https://youtu.be/5jiqOUljfG8](https://youtu.be/5jiqOUljfG8)

2. [https://youtu.be/KNBneUpFaGo](https://youtu.be/KNBneUpFaGo)

3. Add kovan-fork to Development networks:
`brownie networks add Development kovan-fork host=http://127.0.0.1 cmd=ganache-cli  mnemonic=brownie port=8545 accounts=10 evm_version=istanbul fork=kovan gas_limit=12000000 name="Ganache-CLI (Kovan Fork)" timeout=120`

## Usage

1. Open the Brownie console. Starting the console launches a fresh [Ganache](https://www.trufflesuite.com/ganache) instance in the background.

    ```bash
    $ brownie console
    Brownie v1.9.0 - Python development framework for Ethereum

    ReactMixProject is the active project.
    Launching 'ganache-cli'...
    Brownie environment is ready.
    ```

2. Run the [deployment script](scripts/deploy.py) to deploy the project's smart contracts.

    ```python
    >>> run("deploy")
    Running 'scripts.deploy.main'...
    Transaction sent: 0xd1000d04fe99a07db864bcd1095ddf5cb279b43be8e159f94dbff9d4e4809c70
    Gas price: 0.0 gwei   Gas limit: 6721975
    SolidityStorage.constructor confirmed - Block: 1   Gas used: 110641 (1.65%)
    SolidityStorage deployed at: 0xF104A50668c3b1026E8f9B0d9D404faF8E42e642

    Transaction sent: 0xee112392522ed24ac6ab8cc8ba09bfe51c5d699d9d1b39294ba87e5d2a56212c
    Gas price: 0.0 gwei   Gas limit: 6721975
    VyperStorage.constructor confirmed - Block: 2   Gas used: 134750 (2.00%)
    VyperStorage deployed at: 0xB8485421abC325D172652123dBd71D58b8117070
    ```

3. While Brownie is still running, start the React app in a different terminal.

    ```bash
    # make sure to use a different terminal, not the brownie console
    cd client
    yarn start
    ```

4. Connect Metamask to the local Ganache network. In the upper right corner, click the network dropdown menu. Select `Localhost 8545`, or:

    ```bash
    New Custom RPC
    http://localhost:8545
    ```

5. Interact with the smart contracts using the web interface or via the Brownie console.

    ```python
    # get the newest vyper storage contract
    >>> vyper_storage = VyperStorage[-1]

    # the default sender of the transaction is the contract creator
    >>> vyper_storage.set(1337)
    ```

    Any changes to the contracts from the console should show on the website after a refresh, and vice versa.

## Ending a Session

When you close the Brownie console, the Ganache instance also terminates and the deployment artifacts are deleted.

To retain your deployment artifacts (and their functionality) you can launch Ganache yourself prior to launching Brownie. Brownie automatically attaches to the ganache instance where you can deploy the contracts. After closing Brownie, the chain and deployment artifacts will persist.

## Switching Networks

```sh
export WEB3_INFURA_PROJECT_ID=YourProjectID
brownie console --network mainnet-fork
```

## Running Tests and Code Coverage

The RenPool depends heavily on Ren smart contracts to interact with the RenVM.
Ren smart contracts have been deployed independently by the Ren team and their addresses can be found in
<https://renproject.github.io/ren-client-docs/contracts/deployments/>.
The `test/ren` folder contains checks to verify that these contract addresses.

Our test suite is designed to run on local forks of networks where the Ren smart contracts have been already deployed.
Currently these networks are _mainnet_ and _kovan_.
To run the test suite against a _kovan_ fork.

```sh
yarn test
```

On the other hand,
if you want to run these tests against a _mainnet_ fork.

```sh
yarn test:mainnet
```

Runs the test suite and reports gas usage at then end.

```sh
yarn test:gas
```

Run test coverage.
Coverage report is written to `coverage/index.html`.

```sh
yarn coverage
```

Run `solhint` (Solidity linter).

```sh
yarn lint
```

> These `yarn` scripts are declared in `package.json`.

## Running Static Analysis

We use the [Slither](https://github.com/crytic/slither) to run static analysis on the RenPool contract.
Slither can run on a Hardhat application, so you only need to install Slither.

```sh
pip3 install slither-analyzer
```

To run it

```sh
slither .
```

See <https://github.com/crytic/slither> for more information.

The static analysis has been integrated into our pipeline with GitHub Actions.
To see the result of the analysis,
see <https://github.com/Ethernautas/renpool/actions/workflows/analysis.yaml>.

## Deploying to a Live Network

To deploy your contracts to the mainnet or one of the test nets, first modify [`scripts/deploy.py`](`scripts/deploy.py`) to [use a funded account](https://eth-brownie.readthedocs.io/en/stable/account-management.html).

Then:

```sh
yarn deploy --network kovan
```

Replace `kovan` with the name of the network you wish you use.
You may also wish to adjust Brownie's [network settings](https://eth-brownie.readthedocs.io/en/stable/network-management.html).

For contracts deployed on a live network, the deployment information is stored permanently unless you:

- Delete or rename the contract file or
- Manually remove the `client/src/artifacts/` directory
