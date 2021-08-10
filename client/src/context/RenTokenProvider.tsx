import React, { FC, useState, useEffect, createContext } from 'react'
import { Contract } from '@ethersproject/contracts'
import { BigNumber } from '@ethersproject/bignumber'
import { CONTRACT_NAMES } from '../constants'
import { useActiveWeb3React } from '../hooks/useActiveWeb3React'
import { useContract } from '../hooks/useContract'

interface CtxValue {
  renToken: Contract | undefined
  accountBalance: BigNumber
}

/**
 * The defaultValue argument is ONLY used when a component does not have a matching
 * Provider above it in the tree. This can be helpful for testing components in isolation
 * without wrapping them. Note: passing undefined as a Provider value does not cause
 * consuming components to use defaultValue.
 */
const defaultValue: CtxValue = {
  renToken: undefined,
  accountBalance: BigNumber.from(0),
}

export const RenTokenContext = createContext<CtxValue>(defaultValue)

export const RenTokenProvider: FC = ({
  children,
}) => {
  const { library, account } = useActiveWeb3React()

  const renToken = useContract(CONTRACT_NAMES.RenToken)

  const [balance, setBalance] = useState<BigNumber>(BigNumber.from(0))

  useEffect(() => {
    if (library == null || renToken == null || account == null) return

    const query = async () => {
      const _balance: BigNumber = await renToken.balanceOf(account, { gasLimit: 60000 })
      setBalance(_balance)
    }

    query()

    // Listen for changes on an Ethereum address
    const fromMe = renToken.filters.Transfer(account, null)
    library.on(fromMe, query)

    const toMe = renToken.filters.Transfer(null, account)
    library.on(toMe, query)

    // Remove listener when the component is unmounted
    return () => {
      library.removeAllListeners(toMe)
      library.removeAllListeners(fromMe)
    }
  }, [library, renToken, account])

  return (
    <RenTokenContext.Provider
      value={{
        renToken,
        accountBalance: balance,
      }}
    >
      {children}
    </RenTokenContext.Provider>
  )
}