const RenPool= require('./artifacts/contracts/RenPool.sol/RenPool.json');
const RenPoolFactory = require('./artifacts/contracts/RenPoolFactory.sol/RenPoolFactory.json');
const IERC20Standard = require('./artifacts/@renproject/gateway-sol/contracts/Gateway/interfaces/IERC20Standard.sol/IERC20Standard.json');
const IDarknodeRegistry = require('./artifacts/interfaces/IDarknodeRegistry.sol/IDarknodeRegistry.json');
const deployments = require('./ren-deployments.js');

module.exports = {
    RenPool,
    RenPoolFactory,
    IERC20Standard,
    IDarknodeRegistry,
    deployments,
}
