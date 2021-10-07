pragma solidity 0.6.12;

//SPDX-License-Identifier: UNLICENSED

import "./CustomAccessControl.sol";

abstract contract TimelockRole is CustomAccessControl {
    bytes32 public constant ROLE_COMMUNITY = keccak256("ROLE_COMMUNITY");
    
    constructor () public {
        _setRoleAdmin(ROLE_COMMUNITY, ROLE_COMMUNITY);
    }
}

contract Timelock is TimelockRole {
    struct job{
        uint256 id;
        uint256 state;
        string action;
        bytes32 arg0;
        address arg1;
        uint256 queued;
    }
    
    address public TOKEN;
    uint256 public LOCK_PERIOD;
    mapping (uint256 => job) public JOB_DATA;
    uint256 public LAST_ID;
    
    bytes32 public constant CONST_CHANGE_PERIOD = keccak256("changePeriod");
    bytes32 public constant CONST_GRANT_ROLE = keccak256("grantRole");
    bytes32 public constant CONST_REVOKE_ROLE = keccak256("revokeRole");
    bytes32 public constant CONST_RENOUNCE_ROLE = keccak256("renounceRole");

    event JobQueued (uint256 id);
    
    constructor (address token, uint256 lockPeriod) public {
        require(token != address(0), "Token should not be zero-address");
        
        TOKEN = token;
        LOCK_PERIOD = lockPeriod;
        LAST_ID = 0;

        _setupRole(ROLE_COMMUNITY, msg.sender);
    }
    
    modifier JobAlive (uint256 id) {
        require(JOB_DATA[id].id > 0, "There is no job with id");
        require(JOB_DATA[id].state == 0, "Already deactivated job");
        _;
    }
    
    function whenExecutable (uint256 id) public view JobAlive(id) returns (uint256) {
        return JOB_DATA[id].queued + LOCK_PERIOD;
    }
    
    function isExecutable (uint256 id) public view JobAlive(id) returns (bool) {
        return block.number >= whenExecutable(id);
    }
    
    function queueJob (string calldata action, bytes32 arg0, address arg1) external OnlyFor(ROLE_COMMUNITY) returns (uint256) {
        uint256 nextID = LAST_ID + 1;
        
        JOB_DATA[nextID] = job(nextID, 0, action, arg0, arg1, block.number);
        
        emit JobQueued(nextID);
        LAST_ID = nextID;
        return nextID;
    }
    
    function executeJob (uint256 id) external OnlyFor(ROLE_COMMUNITY) {
        require(isExecutable(id) == true, "Job isn't ready");
        
        JOB_DATA[id].state = 1;
        
        if(keccak256(abi.encodePacked(JOB_DATA[id].action)) == CONST_CHANGE_PERIOD){
            _changePeriod(uint256(JOB_DATA[id].arg0));
            return;
        }
        
        IAccessControl tokenObj = IAccessControl(TOKEN);
        if(keccak256(abi.encodePacked(JOB_DATA[id].action)) == CONST_GRANT_ROLE){
            tokenObj.grantRole(JOB_DATA[id].arg0,JOB_DATA[id].arg1);
            return;
        }
        if(keccak256(abi.encodePacked(JOB_DATA[id].action)) == CONST_REVOKE_ROLE){
            tokenObj.revokeRole(JOB_DATA[id].arg0,JOB_DATA[id].arg1);
            return;
        }
        if(keccak256(abi.encodePacked(JOB_DATA[id].action)) == CONST_RENOUNCE_ROLE){
            tokenObj.renounceRole(JOB_DATA[id].arg0,JOB_DATA[id].arg1);
            return;
        }
    }
    
    function cancelJob (uint256 id) external OnlyFor(ROLE_COMMUNITY) JobAlive(id) {
        JOB_DATA[id].state = 2;
    }
    
    function _changePeriod (uint256 lockPeriod) private OnlyFor(ROLE_COMMUNITY) {
        LOCK_PERIOD = lockPeriod;
    }
}