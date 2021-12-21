// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@renproject/gateway-sol/contracts/Gateway/interfaces/IGatewayRegistry.sol";
import "../interfaces/IDarknodeRegistry.sol";
import "../interfaces/IDarknodePayment.sol";
import "../interfaces/IClaimRewardsV1.sol";
// TODO: Ownable + Ownable.initialize(_owner);

contract RenPool {
	uint8 public constant DECIMALS = 18;

	address public owner; // This will be our address, in case we need to refund everyone
	address public nodeOperator;
	address public darknodeID;

	bytes public publicKey;
	// ^ What happens if we register and deregister and register back again?

	uint256 public bond;
	uint256 public totalPooled;
	uint256 public totalWithdrawalRequested;
	uint256 public ownerFee; // Percentage
	uint256 public nodeOperatorFee; // Percentage

	bool public isLocked;
  // ^ we could use enum instead POOL_STATUS = { OPEN /* 0 */, CLOSE /* 1 */ }
  bool public isRegistered;

	mapping(address => uint256) public balances;
	mapping(address => uint256) public withdrawalRequests;
  mapping(address => uint256) public nonces;

	IERC20 public renToken;
	IDarknodeRegistry public darknodeRegistry;
	IDarknodePayment public darknodePayment;
	IClaimRewardsV1 public claimRewards;
	IGatewayRegistry public gatewayRegistry;

	event RenDeposited(address indexed _from, uint256 _amount);
	event RenWithdrawn(address indexed _from, uint256 _amount);
	event RenWithdrawalRequested(address indexed _from, uint256 _amount);
  event RenWithdrawalRequestFulfilled(address indexed _from, uint256 _amount);
	event RenWithdrawalRequestCancelled(address indexed _from, uint256 _amount);
	event EthDeposited(address indexed _from, uint256 _amount);
	event EthWithdrawn(address indexed _from, uint256 _amount);
	event PoolLocked();
	event PoolUnlocked();
  event RewardsClaimed(address indexed _from, uint256 _amount, uint256 _nonce);
  event RewardsMinted(address indexed _from, uint256 _mintedAmount);

	/**
	 * @notice Deploy a new RenPool instance.
	 *
	 * @param _renTokenAddr The REN token contract address.
	 * @param _darknodeRegistryAddr The DarknodeRegistry contract address.
	 * @param _darknodePaymentAddr The DarknodePayment contract address.
	 * @param _claimRewardsAddr The ClaimRewardsV1 contract address.
	 * @param _gatewayRegistryAddr The GatewayRegistry contract address.
	 * @param _owner The protocol's owner address. Possibly a multising wallet.
	 * @param _nodeOperator The protocol's node operator address.
	 * @param _bond The amount of REN tokens required to register a darknode.
	 */
	constructor(
		address _renTokenAddr,
		address _darknodeRegistryAddr,
		address _darknodePaymentAddr,
		address _claimRewardsAddr,
		address _gatewayRegistryAddr,
		address _owner,
    address _nodeOperator,
		uint256 _bond
	)
	{
		owner = _owner;
		nodeOperator = _nodeOperator;
		renToken = IERC20(_renTokenAddr);
		darknodeRegistry = IDarknodeRegistry(_darknodeRegistryAddr);
		darknodePayment = IDarknodePayment(_darknodePaymentAddr);
		claimRewards = IClaimRewardsV1(_claimRewardsAddr);
		gatewayRegistry = IGatewayRegistry(_gatewayRegistryAddr);
		bond = _bond;
		isLocked = false;
    isRegistered = false;
		totalPooled = 0;
    totalWithdrawalRequested = 0;
		ownerFee = 5;
		nodeOperatorFee = 5;
	}

	modifier onlyNodeOperator() {
		require (
			msg.sender == nodeOperator,
			"RenPool: Unauthorized"
		);
		_;
	}

	modifier onlyOwnerNodeOperator() {
		require (
			msg.sender == owner || msg.sender == nodeOperator,
			"RenPool: Unauthorized"
		);
		_;
	}

	modifier onlyOwner() {
		require (
			msg.sender == owner,
			"RenPool: Unauthorized"
		);
		_;
	}

	/**
	 * @notice Lock pool so that no direct deposits/withdrawals can
	 * be performed.
	 */
	function _lockPool() private {
		isLocked = true;
		emit PoolLocked();
	}

  function _deregisterDarknode() private {
    darknodeRegistry.deregister(darknodeID);
    isRegistered = false;
  }

	function unlockPool() external onlyOwnerNodeOperator {
		require(renToken.balanceOf(address(this)) > 0, "RenPool: Pool balance is zero");
		isLocked = false;
		emit PoolUnlocked();
	}

	/**
	 * @notice Deposit REN into the RenPool contract. Before depositing,
	 * the transfer must be approved in the REN contract. In case the
	 * predefined bond is reached, the pool is locked preventing any
	 * further deposits or withdrawals.
	 *
	 * @param _amount The amount of REN to be deposited into the pool.
	 */
	function deposit(uint256 _amount) external {
		address sender = msg.sender;

		require(!isLocked, "RenPool: Pool is locked");
		require(_amount > 0, "RenPool: Invalid amount");
		require(_amount + totalPooled <= bond, "RenPool: Amount surpasses bond");

		balances[sender] += _amount;
		totalPooled += _amount;

		emit RenDeposited(sender, _amount);

		if (totalPooled == bond) {
			_lockPool();
		}

		require(renToken.transferFrom(sender, address(this), _amount), "RenPool: Deposit failed");
	}

	/**
     * @notice Withdraw REN token to the user's wallet from the RenPool smart contract.
     * Cannot be called if the pool is locked.
     *
     * @param _amount The amount of REN to be withdrawn by `sender`.
	 */
	function withdraw(uint256 _amount) external {
		address sender = msg.sender;
		uint256 senderBalance = balances[sender];

		require(_amount > 0, "RenPool: Invalid amount");
		require(senderBalance >= _amount, "RenPool: Insufficient funds");
		require(!isLocked, "RenPool: Pool is locked");

		totalPooled -= _amount;
		balances[sender] -= _amount;

		require(
			renToken.transfer(sender, _amount),
			"RenPool: Withdraw failed"
		);

		emit RenWithdrawn(sender, _amount);
	}

	/**
   * @notice Requesting a withdraw in case the pool is locked. The amount
   * that needs to be withdrawn will be replaced by another user using the
   * fulfillWithdrawalRequest method.
	 *
	 * @param _amount The amount of REN to be withdrawn.
	 *
	 * @dev Users can have up to a single request active. In case of several
	 * calls to this method, only the last request will be preserved.
	 */
	function requestWithdrawal(uint256 _amount) external {
		address sender = msg.sender;
		uint256 senderBalance = balances[sender];

		require(_amount > 0, "RenPool: Invalid amount");
		require(senderBalance >= _amount, "RenPool: Insufficient funds");
		require(isLocked, "RenPool: Pool is not locked");

		withdrawalRequests[sender] = _amount;
    totalWithdrawalRequested += _amount;

    if(isRegistered && totalWithdrawalRequested > bond / 2) {
      _deregisterDarknode();
    }

		emit RenWithdrawalRequested(sender, _amount);
	}

	/**
   * @notice User wanting to fulfill the withdraw request will pay the amount
	 * the user wanting to withdraw his money.
	 *
	 * @param _target The amount of REN to be withdrawn.
	 */
	function fulfillWithdrawalRequest(address _target) external {
		address sender = msg.sender;
		uint256 amount = withdrawalRequests[_target];

    require(amount > 0, "RenPool: invalid amount");
		require(isLocked, "RenPool: Pool is not locked");

		balances[sender] += amount;
		balances[_target] -= amount;
    totalWithdrawalRequested -= amount;

		delete withdrawalRequests[_target];

		// Transfer funds from sender to _target
		require(
			renToken.transferFrom(sender, address(this), amount),
			"RenPool: Deposit failed"
		);
		require(
			renToken.transfer(_target, amount),
			"RenPool: Refund failed"
		);

    emit RenWithdrawalRequestFulfilled(sender, amount);
	}

  function cancelWithdrawalRequest() external {
    address sender = msg.sender;
    uint256 amount = withdrawalRequests[sender];

    require(amount > 0, "RenPool: invalid amount");

    totalWithdrawalRequested -= amount;

    delete withdrawalRequests[sender];

    emit RenWithdrawalRequestCancelled(sender, amount);
  }

	/**
	 * @notice Return REN balance for the given address.
	 *
	 * @param _target Address to be queried.
	 */
	function balanceOf(address _target) external view returns(uint) {
		return balances[_target];
	}

	/**
	 * @notice Transfer bond to the darknodeRegistry contract prior to
	 * registering the darknode.
	 */
	function approveBondTransfer() external onlyNodeOperator {
		require(isLocked, "RenPool: Pool is not locked");

		require(
			renToken.approve(address(darknodeRegistry), bond),
			"RenPool: Bond transfer failed"
		);
	}

	/**
	 * @notice Register a darknode and transfer the bond to the darknodeRegistry
	 * contract. Before registering, the bond transfer must be approved in the
	 * darknodeRegistry contract (see approveTransferBond). The caller must
	 * provide a public encryption key for the darknode. The darknode will remain
	 * pending registration until the next epoch. Only after this period can the
	 * darknode be deregistered. The caller of this method will be stored as the
	 * owner of the darknode.
	 *
	 * @param _darknodeID The darknode ID that will be registered.
	 * @param _publicKey The public key of the darknode. It is stored to allow
	 * other darknodes and traders to encrypt messages to the trader.
	 */
	function registerDarknode(address _darknodeID, bytes calldata _publicKey) external onlyNodeOperator {
		require(isLocked, "RenPool: Pool is not locked");

		darknodeRegistry.register(_darknodeID, _publicKey);

    isRegistered = true;
		darknodeID = _darknodeID;
		publicKey = _publicKey;
	}

	/**
	 * @notice Deregister a darknode. The darknode will not be deregistered
	 * until the end of the epoch. After another epoch, the bond can be
	 * refunded by calling the refund method.
	 *
	 * @dev We don't reset darknodeID/publicKey values after deregistration in order
	 * to being able to call refund.
	 */
	function deregisterDarknode() external onlyOwnerNodeOperator {
    _deregisterDarknode();
	}

	/**
	 * @notice Refund the bond of a deregistered darknode. This will make the
	 * darknode available for registration again. Anyone can call this function
	 * but the bond will always be refunded to the darknode owner.
	 *
	 * @dev No need to reset darknodeID/publicKey values after refund.
	 */
	function refundBond() external {
		darknodeRegistry.refund(darknodeID);
	}

	/**
	 * @notice Allow ETH deposits in case gas is necessary to pay for transactions.
	 */
	receive() external payable {
		emit EthDeposited(msg.sender, msg.value);
	}

	/**
	 * @notice Allow node operator to withdraw any remaining gas.
	 */
	function withdrawGas() external onlyNodeOperator {
		uint256 balance = address(this).balance;
		payable(nodeOperator).transfer(balance);
		emit EthWithdrawn(nodeOperator, balance);
	}

  function getDarknodeBalance(string memory _assetSymbol) external view returns(uint256) {
    return gatewayRegistry.getTokenBySymbol(_assetSymbol).balanceOf(address(this));
  }

	/**
	 * @notice Claim darknode rewards.
	 *
	 * @param _assetSymbol The asset being claimed. e.g. "BTC" or "DOGE".
	 * @param _recipientAddress The Ethereum address to which the assets are
	 * being withdrawn to. This same address must then call `mint` on
	 * the asset's Ren Gateway contract.
   * @param _amount The amount of the token being minted, in its smallest
	 * denomination (e.g. satoshis for BTC).
   *
   * @dev When RenVM sees the claim, it will produce a signature which needs
   * to be submitted to the asset's Ren Gateway contract on Ethereum. The
   * signature has to be fetched via a JSON-RPC request made to the associated
   * lightnode (https://lightnode-devnet.herokuapp) with the transaction
   * details from the claimRewardsToEthereum call.
	 */
	function claimRewardsToChain(
		string memory _assetSymbol,
		address _recipientAddress,
		uint256 _amount
	)
		external
    returns(uint256)
	{
    address sender = msg.sender;

	  // TODO: check that sender has the amount to be claimed
    // uint256 balance = gatewayRegistry.getTokenBySymbol(_assetSymbol).balanceOf(address(this));
		uint256 fractionInBps = 10_000; // TODO: this should be the share of the user for the given token
		uint256 nonce = claimRewards.claimRewardsToEthereum(_assetSymbol, _recipientAddress, fractionInBps);
    // TODO: Use claimReardsToChain instead
    nonces[sender] = nonce;
    emit RewardsClaimed(sender, _amount, nonce);
    return nonce;
  }

  /**
   * @notice mint verifies a mint approval signature from RenVM and creates
   * tokens after taking a fee for the `_feeRecipient`.
   *
   * @param _amount The amount of the token being minted, in its smallest
   * denomination (e.g. satoshis for BTC).
   * @param _sig The signature of the hash of the following values:
   * (pHash, amount, msg.sender, nHash), signed by the mintAuthority. Where
   * mintAuthority refers to the address of the key that can sign mint requests.
   *
   * @dev You'll need to make an RPC request to the RenVM after calling claimRewardsToChain
   * in order to get the signature from the mint authority.
   * Source: https://renproject.github.io/ren-client-docs/contracts/integrating-contracts#writing-a-mint-function
   */
  function mintRewards(
		string memory _assetSymbol,
		address _recipientAddress,
		uint256 _amount,
    uint256 _nonce,
    bytes memory _sig
  )
    external
  {
    // _pHash (payload hash) The hash of the payload associated with the
    // mint, ie, asset symbol and recipient address.
    bytes32 pHash = keccak256(abi.encode(_assetSymbol, _recipientAddress));

    // _nHash (nonce hash) The hash of the nonce, amount and pHash.
		bytes32 nHash = keccak256(abi.encode(_nonce, _amount, pHash));

    uint256 mintAmount = gatewayRegistry.getGatewayBySymbol(_assetSymbol).mint(pHash, _amount, nHash, _sig);
    console.log("mintAmount", mintAmount);

    emit RewardsMinted(msg.sender, mintAmount);
	}
}
