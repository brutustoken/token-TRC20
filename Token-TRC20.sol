pragma solidity >=0.8.0;
// SPDX-License-Identifier: Apache-2.0


library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {return 0;}
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

contract Ownable {
    address public owner;
    address public nextOwner;
    uint256 public ownershipTransferDeadline;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        nextOwner = newOwner;
        ownershipTransferDeadline = block.timestamp + 1 days;
    }

    function reciveOwnership() public {
        require(msg.sender == nextOwner, "Caller is not the next owner");
        require(block.timestamp <= ownershipTransferDeadline, "Ownership transfer deadline passed");

        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        nextOwner = address(0);
        ownershipTransferDeadline = 0;

    }

    function cancelOwnershipTransfer() public onlyOwner {
        require(block.timestamp > ownershipTransferDeadline, "Ownership transfer deadline not yet passed");

        nextOwner = address(0);
        ownershipTransferDeadline = 0;
    }

}

contract BlackList is Ownable {

    mapping (address => bool) public isBlackListed;
    mapping (address => string) public blacklistReason;


    function addBlackList (address _evilUser, string memory _reason) public onlyOwner {
        isBlackListed[_evilUser] = true;
        blacklistReason[_evilUser] = _reason;

        emit AddedBlackList(_evilUser);
    }

    function removeBlackList (address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    event AddedBlackList(address indexed _user);
    event RemovedBlackList(address indexed _user);

}

contract TRC20 is BlackList {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint256 private _limitIssue;
    uint256 private _limitBurn;


    event DestroyedBlackFunds(address indexed _blackListedUser, uint256 _balance);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event IssueLimit(uint256 old_limit,uint256 new_limit);
    event BurnLimit(uint256 old_limit,uint256 new_limit);



    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(amount > 0, "Transfer amount must be greater than zero");
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(amount > 0, "Transfer amount must be greater than zero");
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(addedValue > 0, "Increase amount must be greater than zero");
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(subtractedValue > 0, "Decrease value must be greater than zero");
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    function issue(uint256 amount) public onlyOwner {
        require(amount > 0, "Issue amount must be greater than zero");
        _mint(msg.sender, amount);
    }
        
    function redeem(uint256 amount) public onlyOwner {
        require(amount > 0, "Redeem amount must be greater than zero");
        _burn(msg.sender, amount);
    }

    function increaseIssueLimit(uint256 amount) public onlyOwner{
        _setLimitIssue(amount);
    }

    function reduceBurnLimit(uint256 amount) public onlyOwner{
        _setLimitBurn(amount);
    }

    function destroyBlackFunds (address _blackListedUser) public onlyOwner {
        require(isBlackListed[_blackListedUser], "The user must be blacklisted");
        uint256 dirtyFunds = balanceOf(_blackListedUser);
        _burnFrom(_blackListedUser, dirtyFunds);
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }

    function _transfer(address sender, address recipient, uint256 amount) virtual internal {
        require(!isBlackListed[sender], string(abi.encodePacked("Sender is Blacklisted, Reason: ",blacklistReason[sender])));
        require(!isBlackListed[recipient], string(abi.encodePacked("Recipient is Blacklisted, Reason: ",blacklistReason[recipient])));
        
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) virtual internal {
        require(account != address(0), "Mint to the zero address");
        require(_totalSupply.add(amount) > _limitIssue, string(abi.encodePacked("limit is reached: ",_limitIssue)) );

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 value) virtual internal {
        require(account != address(0), "Burn from the zero address");
        require(_limitBurn > _totalSupply.sub(value), string(abi.encodePacked("limit is reached: ",_limitBurn)) );

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    function _setLimitIssue(uint256 limit) virtual internal {
       emit IssueLimit(_limitIssue, limit);
       _limitIssue = limit;
    }

    function _setLimitBurn(uint256 limit) virtual internal {
        emit BurnLimit(_limitBurn, limit);
       _limitBurn = limit;
    }

    function _approve(address owner, address spender, uint256 value) virtual internal {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _burnFrom(address account, uint256 amount) virtual internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }
}

contract TRC20Detailed is TRC20 {
    string public name;
    string public symbol;
    uint8 public decimals;

    constructor (string memory _name, string memory _symbol, uint8 _decimals, uint256 initialSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _mint(msg.sender, initialSupply * 10 ** uint256(decimals));
        _setLimitIssue(initialSupply * 10 ** uint256(decimals));
        _setLimitBurn(initialSupply * 10 ** uint256(decimals));
    }

}