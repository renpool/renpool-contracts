require('dotenv');
const {
  ethers: {
    getSigners,
    getContractFactory,
    Contract,
    BigNumber: { from: bn },
    constants: { AddressZero },
  },
  network: {
    provider,
  },
} = require('hardhat');
const { expect } = require('chai');

describe('RenPoolFactory contract test', function () {

  let owner, nodeOperator, alice, bob;
  let renPoolFactory;

  let snapshotID;

  before(async () => {
    [owner, nodeOperator, alice, bob] = await getSigners();

    const RenPoolFactory = await getContractFactory('RenPoolFactory');
    renPoolFactory = await RenPoolFactory.connect(owner).deploy();
    await renPoolFactory.deployed();

    snapshotID = await provider.request({ method: 'evm_snapshot', params: [] });
  });

  afterEach(async () => {
    await provider.request({ method: 'evm_revert', params: [snapshotID] });
    snapshotID = await provider.request({ method: 'evm_snapshot', params: [] });
  });

  it('should set the constructor args to the supplied values', async function () {
    expect(await renPoolFactory.owner()).to.equal(owner.address);
    expect(await renPoolFactory.getPools()).to.be.instanceof(Array);
    expect(await renPoolFactory.getPools()).to.deep.equal([]);
  });

  describe('deployNewPool', function () {

    it('should deploy and append a new pool', async function () {
      await renPoolFactory.connect(nodeOperator).deployNewPool(
        AddressZero,
        AddressZero,
        AddressZero,
        AddressZero,
        AddressZero,
        0,
      );

      const pools = await renPoolFactory.getPools();

      expect(pools.length).to.equal(1);

      const RenPool = await getContractFactory('RenPool');
      const renPool = await RenPool.attach(pools[0]);

      expect(await renPool.owner()).to.equal(owner.address);
      expect(await renPool.nodeOperator()).to.equal(nodeOperator.address);
      expect(await renPool.bond()).to.equal(0);
      expect(await renPool.isLocked()).to.equal(false);
      expect(await renPool.totalPooled()).to.equal(0);
    });

  });

});
