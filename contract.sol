// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MonthlyWithdrawal {
    address public initialAdmin = 0x00De4B13153673BCAE2616b67bf822500d325Fc3;
    mapping(address => bool) public isAdmin;
    address[] public allowedAddresses;
    mapping(address => uint256) public lastWithdrawalTime;

    uint256 public constant WITHDRAWAL_AMOUNT = 0.1 ether;
    uint256 public constant TIME_INTERVAL = 30 days;

    event Withdrawal(address indexed user, uint256 amount, string note);
    event AdminAdded(address indexed newAdmin);
    event AdminRemoved(address indexed admin);
    event MemberAdded(address indexed member);
    event MemberRemoved(address indexed member);

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

    constructor() {
        isAdmin[initialAdmin] = true;
        allowedAddresses.push(0xb48E8dA63c2aFc5633702B7acf4BDe830c1dE48b);
        allowedAddresses.push(0x1d671d1B191323A38490972D58354971E5c1cd2A);
        allowedAddresses.push(0x7d03C5c37f77Fd01211334B9115CA108C84E8f3B);
        allowedAddresses.push(0x00De4B13153673BCAE2616b67bf822500d325Fc3);
        allowedAddresses.push(0x1dCD8763c01961C2BbB5ed58C6E51F55b1378589);
        allowedAddresses.push(0x890154e4179452858EEa60ed81B8E366010D0b8E);
        allowedAddresses.push(0x7a738EfFD10bF108b7617Ec8E96a0722fa54C547);
    }

    // Admin functions
    function addAdmin(address newAdmin) external onlyAdmin {
        require(!isAdmin[newAdmin], "Already an admin");
        isAdmin[newAdmin] = true;
        emit AdminAdded(newAdmin);
    }

    function removeAdmin(address admin) external onlyAdmin {
        require(isAdmin[admin], "Not an admin");
        isAdmin[admin] = false;
        emit AdminRemoved(admin);
    }

    // Manage allowed addresses
    function addMember(address newMember) external onlyAdmin {
        require(!isAllowed(newMember), "Already a member");
        allowedAddresses.push(newMember);
        emit MemberAdded(newMember);
    }

    function removeMember(address member) external onlyAdmin {
        require(isAllowed(member), "Not a member");
        for (uint256 i = 0; i < allowedAddresses.length; i++) {
            if (allowedAddresses[i] == member) {
                allowedAddresses[i] = allowedAddresses[allowedAddresses.length - 1];
                allowedAddresses.pop();
                emit MemberRemoved(member);
                return;
            }
        }
    }

    // Check if the address is in the allowed list
    function isAllowed(address user) public view returns (bool) {
        for (uint256 i = 0; i < allowedAddresses.length; i++) {
            if (allowedAddresses[i] == user) {
                return true;
            }
        }
        return false;
    }

    // Withdraw function with note requirement
    function withdraw(string memory note) external onlyAllowed canWithdraw validNoteLength(note) {
        require(address(this).balance >= WITHDRAWAL_AMOUNT, "Insufficient contract balance");

        lastWithdrawalTime[msg.sender] = block.timestamp;
        payable(msg.sender).transfer(WITHDRAWAL_AMOUNT);

        emit Withdrawal(msg.sender, WITHDRAWAL_AMOUNT, note);
    }

    // Receive ETH to the contract
    receive() external payable {}

    // Fallback function for receiving ETH
    fallback() external payable {}

    // Get the remaining time until the next withdrawal
    function getRemainingTime() external view returns (uint256) {
        if (block.timestamp >= lastWithdrawalTime[msg.sender] + TIME_INTERVAL) {
            return 0;
        } else {
            return (lastWithdrawalTime[msg.sender] + TIME_INTERVAL) - block.timestamp;
        }
    }
}
