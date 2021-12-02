// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./RenPool.sol";

contract RenPoolFactory {
  address public owner;
  address[] public pools;

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
   * @param _owner The protocol owner's address. Possibly a multising wallet.
   * @param _bond The amount of REN tokens required to register a darknode.
   */
  function deployPool(
    address _renTokenAddr,
    address _darknodeRegistryAddr,
    address _darknodePaymentAddr,
    address _claimRewardsAddr,
    address _gatewayRegistryAddr,
    address _owner,
    uint256 _bond
  )
    external
    returns(uint256)
  {
    // TODO: we should pass nodeOperator = msg.sender as a param
    uint256 addr = new RenPool(
      _renTokenAddr,
      _darknodeRegistryAddr,
      _darknodePaymentAddr,
      _claimRewardsAddr,
      _gatewayRegistryAddr,
      owner,
      _bond
    );

    pools.push(addr);

    return addr;
  }
}

