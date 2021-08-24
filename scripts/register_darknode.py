from brownie import accounts, config, RenPool
from brownie_tokens import MintableForkToken
import constants as C

def main():
  """
  Deploy a RenPool contract to the mainnet-fork, lock the
  pool by providing liquidity and finally register a
  darknode instance.
  See: https://youtu.be/0JrDbvBClEA (brownie tutorial)
  See: https://renproject.github.io/contracts-ts/#/mainnet
  """

  network = C.NETWORKS['MAINNET_FORK']

  if config['networks']['default'] != network:
    raise ValueError(f'Unsupported network, switch to {network}')

  owner = accounts[0]
  nodeOperator = accounts[1]
  user = accounts[2]

  renTokenAddr = C.CONTRACT_ADDRESSES[network].REN_TOKEN
  darknodeRegistryAddr = C.CONTRACT_ADDRESSES[network].DARKNODE_REGISTRY

  renPool = RenPool.deploy(
    renTokenAddr,
    darknodeRegistryAddr,
    owner,
    C.POOL_BOND,
    {'from': nodeOperator}
  )

  renToken = MintableForkToken(renTokenAddr)
  renToken._mint_for_testing(user, C.POOL_BOND)

  renToken.approve(renPool, C.POOL_BOND, {'from': user})
  renPool.deposit(C.POOL_BOND, {'from': user})

  if renPool.isLocked() != True:
    raise ValueError('Pool is not locked')

  renPool.approveBondTransfer({'from': nodeOperator})
  renPool.registerDarknode(user, 'some_public_key', {'from': nodeOperator})

  return renToken, renPool