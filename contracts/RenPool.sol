pragma solidity ^0.8.0;

import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/token/ERC20/ERC20.sol";

contract RenPool {
    ERC20 public renToken;
    address public owner; // This will be our address, in case we need to destroy the contract and refund everyone
    address public admin;
    mapping(address => uint) public balances;
    uint public totalPooled;
    bool public isLocked;
    uint public ownerFee; // Percentage
    uint public adminFee; // Percentage
    uint public target;
    uint8 public constant DECIMALS = 18;

    mapping(address => uint) public withdrawRequests;

    event RenDeposited(address from, uint amount);
    event RenWithdrawn(address from, uint amount);
    event PoolLocked();
    event PoolUnlocked();

    constructor(address _renTokenAddr, address _owner, uint _target) {
        renToken = ERC20(_renTokenAddr);
        owner = _owner;
        admin = msg.sender;
        target = _target; // TODO: we need a set method to be able to update this value
        isLocked = false;
        totalPooled = 0;
        ownerFee = 5;
        adminFee = 5;
    }

    modifier onlyAdmin() {
        require (msg.sender == admin, "You must be the admin of the pool to execute this action.");
        _;
    }

    modifier onlyOwner() {
        require (msg.sender == owner, "You must be the owner to execute this action.");
        _;
    }

    function _lockPool() private {
        isLocked = true;
        emit PoolLocked();
    }

    function deposit(uint _amount) external {
        address sender = msg.sender;

        require(_amount > 0, "Invalid ammount");
        require(_amount + totalPooled <= target, "Amount surpasses pool target");
        require(isLocked == false, "Pool is locked");

        renToken.transferFrom(sender, address(this), _amount);
        // ^ user needs to give allowance first for this transaction to pass.
        // See: https://ethereum.org/nl/developers/tutorials/erc20-annotated-code/
        balances[sender] += _amount; // TODO: do we need to use safeMath?
        totalPooled += _amount;

        emit RenDeposited(sender, _amount);

        if (totalPooled == target) {
            _lockPool(); // Locking the pool if target is met
        }
    }

    function withdraw(uint _amount) external {
        address sender = msg.sender;
        uint senderBalance = balances[sender];

        require(senderBalance > 0 && senderBalance >= _amount, "Insufficient funds");
        require(isLocked == false, "Pool is locked, please do a withdraw request");

        totalPooled -= _amount;
        balances[sender] -= _amount;
        renToken.transfer(sender, _amount);

        emit RenWithdrawn(sender, _amount);
    }

    function requestWithdraw(uint _amount) external {
        address sender = msg.sender;
        uint senderBalance = balances[sender];

        require(senderBalance > 0 && senderBalance >= _amount, "Insufficient funds");
        require(isLocked == true, "The pool is not locked, please do a regular withdraw");

        withdrawRequests[sender] = _amount;
    }

    function fullfillWithdrawRequest(address _withdrawRequestAddress) external {
        uint withdrawRequestAmount = withdrawRequests[_withdrawRequestAddress];
        address sender = msg.sender;

        require(isLocked == true, "Pool is not locked");
        require(renToken.transferFrom(sender, address(this), withdrawRequestAmount));

        // Transfering the balance
        balances[sender] += withdrawRequestAmount;
        balances[_withdrawRequestAddress] -= withdrawRequestAmount;

        // withdraw funds
        renToken.transfer(_withdrawRequestAddress, withdrawRequestAmount);

        // removing the user in the queue
        delete withdrawRequests[_withdrawRequestAddress];
    }

    function balanceOf(address _addr) external view returns(uint) {
        return balances[_addr];
    }
}