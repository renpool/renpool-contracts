// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./RenPool.sol";

contract RenPoolFactory {
  address public owner;
  address[] public pools;

  event PoolDeployed(address _from, address _pool);

  constructor() {
    owner = msg.sender;
  }

  /**
   * @notice Deploy a new RenPool instance.
   *
   * @param _renTokenAddr The REN token contract address.
   * @param _darknodeRegistryAddr The DarknodeRegistry contract address.
   * @param _darknodePaymentAddr The DarknodePayment contract address.
   * @param _claimRewardsAddr The ClaimRewardsV1 contract address.
   * @param _gatewayRegistryAddr The GatewayRegistry contract address.
   * @param _bond The amount of REN tokens required to register a darknode.
   */
  function deployNewPool(
    address _renTokenAddr,
    address _darknodeRegistryAddr,
    address _darknodePaymentAddr,
    address _claimRewardsAddr,
    address _gatewayRegistryAddr,
    uint256 _bond
  )
    external
    returns(address)
  {
    address nodeOperator = msg.sender;

    RenPool pool = new RenPool(
      _renTokenAddr,
      _darknodeRegistryAddr,
      _darknodePaymentAddr,
      _claimRewardsAddr,
      _gatewayRegistryAddr,
      owner,
      nodeOperator,
      _bond
    );

    address addr = address(pool);
    pools.push(addr);

    emit PoolDeployed(nodeOperator, addr);

    return addr;
  }

  function getPools() external view returns(address[] memory) {
    return pools;
  }
}

