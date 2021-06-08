pragma solidity ^0.5.0;

interface IGovernance {
    event GovernanceChanged(address oldGovernance, address newGovernance);
    event MinterAdmitted(address target);
    event MinterExpelled(address target);
    
    function governance () external view returns (address);
    function isMinter (address target) external view returns (bool);
    function admitMinter (address target) external;
    function expelMinter (address target) external;
    function succeedGovernance (address newGovernance) external;
}

contract Timelock {
    struct job{
        uint256 id;
        uint256 state;
        string action;
        address arg;
        uint256 queued;
    }
    
    address public COMMUNITY;
    address public TOKEN;
    uint256 public LOCK_PERIOD;
    mapping (uint256 => job) public JOB_DATA;
    uint256 public LAST_ID;
    
    event JobQueued (uint256 id);
    
    constructor (address token, uint256 lockPeriod) public {
        TOKEN = token;
        COMMUNITY = msg.sender;
        LOCK_PERIOD = lockPeriod;
        LAST_ID = 0;
    }
    
    modifier CommunityOnly () {
        require (msg.sender == COMMUNITY, "Only Community can do");
        _;
    }
    
    modifier JobAlive (uint256 id) {
        require(JOB_DATA[id].id > 0, "There is no job with id");
        require(JOB_DATA[id].state == 0, "Already expired job");
        _;
    }
    
    function whenExecutable (uint256 id) public view JobAlive(id) returns (uint256) {
        return JOB_DATA[id].queued + LOCK_PERIOD;
    }
    
    function isExecutable (uint256 id) public view JobAlive(id) returns (bool) {
        return block.number >= whenExecutable(id);
    }
    
    function queueJob (string calldata action, address arg) external CommunityOnly returns (uint256) {
        uint256 nextID = LAST_ID + 1;
        
        JOB_DATA[nextID] = job(nextID, 0, action, arg, block.number);
        
        emit JobQueued(nextID);
        LAST_ID = nextID;
        return nextID;
    }
    
    function cancelJob (uint256 id) external CommunityOnly JobAlive(id) {
        JOB_DATA[id].state = 2;
    }
    
    function executeJob (uint256 id) external CommunityOnly {
        require(isExecutable(id) == true, "Job isnt ready");
        
        JOB_DATA[id].state = 1;
        
        if(keccak256(abi.encodePacked(JOB_DATA[id].action)) == keccak256("changePeriod")){
            _changePeriod(uint256(JOB_DATA[id].arg));
            return;
        }
        
        IGovernance tokenObj = IGovernance(TOKEN);
        if(keccak256(abi.encodePacked(JOB_DATA[id].action)) == keccak256("admitMinter")){
            tokenObj.admitMinter(JOB_DATA[id].arg);
            return;
        }
        if(keccak256(abi.encodePacked(JOB_DATA[id].action)) == keccak256("expelMinter")){
            tokenObj.expelMinter(JOB_DATA[id].arg);
            return;
        }
        if(keccak256(abi.encodePacked(JOB_DATA[id].action)) == keccak256("succeedGovernance")){
            tokenObj.succeedGovernance(JOB_DATA[id].arg);
            return;
        }
    }
    
    function succeedCommunity (address newCommunity) external CommunityOnly {
        COMMUNITY = newCommunity;
    }
    
    function _changePeriod (uint256 lockPeriod) private CommunityOnly {
        LOCK_PERIOD = lockPeriod;
    }
}