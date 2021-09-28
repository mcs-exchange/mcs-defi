pragma solidity 0.6.12;

//SPDX-License-Identifier: UNLICENSED

import "./CustomAccessControl.sol";

abstract contract MCSRole is CustomAccessControl {
    bytes32 public constant ROLE_MINTER = keccak256("ROLE_MINTER");
    bytes32 public constant ROLE_SUPERVISOR = keccak256("ROLE_SUPERVISOR");
    bytes32 public constant ROLE_GOVERNANCE = keccak256("ROLE_GOVERNANCE");
    
    constructor () public {
        _setRoleAdmin(ROLE_SUPERVISOR, ROLE_GOVERNANCE);
        _setRoleAdmin(ROLE_GOVERNANCE, ROLE_GOVERNANCE);
        _setRoleAdmin(ROLE_MINTER, ROLE_GOVERNANCE);
    }
}

contract Emergency is MCSRole {
    mapping (address => bool) private _lockState;
    
    event LockStateChanged (address target, bool lock);

    modifier NotFrozen () {
        require(!_lockState[address(this)], "Token is frozen");
        _;
    }

    modifier NotLocked () {
        require(!_lockState[_msgSender()], "Address is locked");
        _;
    }

    function isFrozen () external view returns (bool) {
        return _lockState[address(this)];
    }

    function isLocked (address target) external view returns (bool) {
        return _lockState[target];
    }
    
    function changeLockState (address target, bool state) public OnlyFor(ROLE_SUPERVISOR) {
        _lockState[target] = state;
        emit LockStateChanged (target, state);
    }

    function freezeToken () external {
        changeLockState(address(this), true);
    }

    function meltToken () external {
        changeLockState(address(this), false);
    }

    function lockAddress (address target) external {
        changeLockState(target, true);
    }

    function unlockAddress (address target) external {
        changeLockState(target, false);
    }
}

contract ERC20 is Emergency {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;

    uint256 private _totalSupply;
    uint256 private immutable _initialSupply;
    
    mapping (address => uint256) internal _supplyByMinter;
    mapping (address => uint256) internal _burnByAddress;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor (
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply
    ) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        
        _mint(_msgSender(), initialSupply);
        _initialSupply = initialSupply;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function initialSupply() external view returns (uint256) {
        return _initialSupply;
    }
    
    function supplyByMinter (address minter) external view returns (uint256) {
        return _supplyByMinter[minter];
    }
    
    function burnByAddress (address by) external view returns (uint256) {
        return _burnByAddress[by];
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address recipient, uint256 amount) external NotFrozen NotLocked returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external NotFrozen NotLocked returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    
    function mint (address to, uint256 quantity) public OnlyFor(ROLE_MINTER) NotFrozen NotLocked {
        _mint(to, quantity);
        _supplyByMinter[_msgSender()] = _supplyByMinter[_msgSender()].add(quantity);
    }
    
    function burn (uint256 quantity) public NotFrozen NotLocked {
        _burn(_msgSender(), quantity);
        _burnByAddress[_msgSender()] = _burnByAddress[_msgSender()].add(quantity);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance"));
    }
}

contract MCS is ERC20 {
    constructor (uint256 initialSupply) public ERC20("MCS","MCS",18,initialSupply) {
        _setupRole(ROLE_SUPERVISOR, msg.sender);
        _setupRole(ROLE_GOVERNANCE, msg.sender);
    }
    
    function token () external view returns (MCS) {
        return MCS(address(this));
    }

    function issue (address to, uint256 quantity) external {
        mint(to, quantity);
    }

    function destroy (uint256 quantity) external {
        burn(quantity);
    }
}