// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
}

contract MonthlyWithdrawal {
    // Constants
    IERC721 public constant MOONSHOTBOT_CONTRACT = IERC721(0x8b13e88EAd7EF8075b58c94a7EB18A89FD729B18);
    address public constant INITIAL_ADMIN = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    uint256 public constant WITHDRAWAL_AMOUNT = 0.1 ether;
    uint256 public constant TIME_INTERVAL = 30 days;

    // State variables
    mapping(address => bool) public isAdmin;
    mapping(address => uint256) public lastWithdrawalTime;
    address[] public allowedAddresses;

    // Events
    event Withdrawal(address indexed user, uint256 amount, string note);
    event AdminAdded(address indexed newAdmin);
    event AdminRemoved(address indexed admin);
    event MemberAdded(address indexed member);
    event MemberRemoved(address indexed member);

    // Constructor
    constructor() {
        isAdmin[INITIAL_ADMIN] = true;
    }

    // Modifiers
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Not an admin");
        _;
    }

    modifier onlyAllowed() {
        require(isAllowed(msg.sender), "Not allowed to withdraw");
        _;
    }

    modifier canWithdraw() {
        require(block.timestamp >= lastWithdrawalTime[msg.sender] + TIME_INTERVAL, "Withdrawal not allowed yet");
        _;
    }

    modifier validNoteLength(string memory note) {
        require(bytes(note).length >= 20, "Note must be at least 20 characters long");
        _;
    }

    // Admin management functions
    function addAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        require(!isAdmin[newAdmin], "Already an admin");
        isAdmin[newAdmin] = true;
        emit AdminAdded(newAdmin);
    }

    function removeAdmin(address admin) external onlyAdmin {
        require(admin != INITIAL_ADMIN, "Cannot remove initial admin");
        require(isAdmin[admin], "Not an admin");
        isAdmin[admin] = false;
        emit AdminRemoved(admin);
    }

    // Member management functions
    function addMember(address newMember) external onlyAdmin {
        require(newMember != address(0), "Invalid member address");
        for (uint256 i = 0; i < allowedAddresses.length; i++) {
            require(allowedAddresses[i] != newMember, "Already a member");
        }
        allowedAddresses.push(newMember);
        emit MemberAdded(newMember);
    }

    function removeMember(address member) external onlyAdmin {
        for (uint256 i = 0; i < allowedAddresses.length; i++) {
            if (allowedAddresses[i] == member) {
                allowedAddresses[i] = allowedAddresses[allowedAddresses.length - 1];
                allowedAddresses.pop();
                emit MemberRemoved(member);
                return;
            }
        }
        revert("Member not found");
    }

    // View functions
    function isAllowed(address user) public view returns (bool) {
        // Check if in allowed addresses list
        for (uint256 i = 0; i < allowedAddresses.length; i++) {
            if (allowedAddresses[i] == user) {
                return true;
            }
        }
        
        // Check if Moonshotbot holder
        return MOONSHOTBOT_CONTRACT.balanceOf(user) > 0;
    }

    function getRemainingTime() external view returns (uint256) {
        if (block.timestamp >= lastWithdrawalTime[msg.sender] + TIME_INTERVAL) {
            return 0;
        }
        return (lastWithdrawalTime[msg.sender] + TIME_INTERVAL) - block.timestamp;
    }

    function getAllowedAddresses() external view returns (address[] memory) {
        return allowedAddresses;
    }

    // Main withdrawal function
    function withdraw(string memory note) external onlyAllowed canWithdraw validNoteLength(note) {
        require(address(this).balance >= WITHDRAWAL_AMOUNT, "Insufficient contract balance");
        
        lastWithdrawalTime[msg.sender] = block.timestamp;
        payable(msg.sender).transfer(WITHDRAWAL_AMOUNT);
        
        emit Withdrawal(msg.sender, WITHDRAWAL_AMOUNT, note);
    }

    // Receive and fallback functions
    receive() external payable {}
    fallback() external payable {}
}
