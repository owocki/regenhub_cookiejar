// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721Enumerable {
    function balanceOf(address owner) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract MonthlyWithdrawal {
    // Error messages
    error NotAdminError(address caller);
    error NotAllowedError(address caller, string reason);
    error InvalidNoteLength(uint256 length, uint256 required);
    error ContractIsPaused();
    error ReentrantCall();
    error InvalidAddress(string reason);
    error AdminError(string reason);
    error MemberError(string reason);
    error WithdrawalError(string reason);
    error TransferFailed(address to, uint256 amount);
    error NFTError(string reason);
    error InsufficientBalance(uint256 available, uint256 required);
    error TimeIntervalError(uint256 remainingTime);
    error BatchSizeError(string reason);

    // Constants made immutable for gas optimization
    IERC721Enumerable public immutable MOONSHOTBOT_CONTRACT;
    address public immutable INITIAL_ADMIN;
    uint256 public constant WITHDRAWAL_AMOUNT = 100000000000000000; // 0.1 ether in wei
    uint256 public constant TIME_INTERVAL = 30 days;
    uint256 public constant MAX_BATCH_SIZE = 50;

    // State variables
    mapping(address => bool) public isAdmin;
    mapping(uint256 => uint256) public lastWithdrawalTimeByNFT;
    mapping(address => uint256) public lastWithdrawalTime;
    mapping(address => bool) public isAllowedMember; // Replaced array with mapping
    bool public isPaused;
    
    // Reentrancy Guard using a more gas-efficient uint256
    uint256 private _notEntered = 1;

    // Events
    event Withdrawal(address indexed user, uint256 amount, string note, uint256 indexed tokenId);
    event AdminAdded(address indexed newAdmin);
    event AdminRemoved(address indexed admin);
    event MemberAdded(address indexed member);
    event MemberRemoved(address indexed member);
    event PauseStateChanged(address indexed admin, bool isPaused);
    event EmergencyWithdrawal(address indexed admin, uint256 amount);
    event ContractInitialized(address moonshotContract, address initialAdmin);

    // Constructor to initialize immutable variables
    constructor(address moonshotbotContract, address initialAdmin) {
        if (moonshotbotContract == address(0)) revert InvalidAddress("Moonshotbot contract address cannot be zero");
        if (initialAdmin == address(0)) revert InvalidAddress("Initial admin address cannot be zero");

        MOONSHOTBOT_CONTRACT = IERC721Enumerable(moonshotbotContract);
        INITIAL_ADMIN = initialAdmin;
        isAdmin[INITIAL_ADMIN] = true;

        emit ContractInitialized(moonshotbotContract, initialAdmin);
    }

    // Modifiers
    modifier nonReentrant() {
        if (_notEntered != 1) revert ReentrantCall();
        _notEntered = 2;
        _;
        _notEntered = 1;
    }

    modifier onlyAdmin() {
        if (!isAdmin[msg.sender]) revert NotAdminError(msg.sender);
        _;
    }

    modifier onlyAllowed() {
        if (!isAllowedMember[msg.sender] && MOONSHOTBOT_CONTRACT.balanceOf(msg.sender) == 0) {
            if (!isAllowedMember[msg.sender]) {
                revert NotAllowedError(msg.sender, "Address is not in the whitelist");
            } else {
                revert NotAllowedError(msg.sender, "Address does not hold any Moonshotbot NFTs");
            }
        }
        _;
    }

    modifier validNoteLength(string memory note) {
        if (bytes(note).length < 20) {
            revert InvalidNoteLength(bytes(note).length, 20);
        }
        _;
    }

    modifier whenNotPaused() {
        if (isPaused) revert ContractIsPaused();
        _;
    }

    // Admin management
    function addAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidAddress("Admin address cannot be zero");
        if (isAdmin[newAdmin]) revert AdminError("Address is already an admin");
        
        isAdmin[newAdmin] = true;
        emit AdminAdded(newAdmin);
    }

    function removeAdmin(address admin) external onlyAdmin {
        if (admin == INITIAL_ADMIN) revert AdminError("Cannot remove initial admin");
        if (!isAdmin[admin]) revert AdminError("Address is not an admin");
        
        isAdmin[admin] = false;
        emit AdminRemoved(admin);
    }

    // Member management - Gas optimized with mapping
    function addMember(address newMember) external onlyAdmin {
        if (newMember == address(0)) revert InvalidAddress("Member address cannot be zero");
        if (isAllowedMember[newMember]) revert MemberError("Address is already a member");
        
        isAllowedMember[newMember] = true;
        emit MemberAdded(newMember);
    }

    function removeMember(address member) external onlyAdmin {
        if (!isAllowedMember[member]) revert MemberError("Address is not a member");
        
        isAllowedMember[member] = false;
        emit MemberRemoved(member);
    }

    // Emergency controls
    function setPaused(bool _isPaused) external onlyAdmin {
        isPaused = _isPaused;
        emit PauseStateChanged(msg.sender, _isPaused);
    }

    // Emergency withdrawal with reentrancy protection
    function emergencyWithdrawAll() external nonReentrant onlyAdmin {
        uint256 balance = address(this).balance;
        if (balance == 0) revert InsufficientBalance(0, 1);
        
        // Update state before transfer (even though there's no state to update, keeping pattern consistent)
        emit EmergencyWithdrawal(msg.sender, balance);
        
        // Transfer funds last
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) revert TransferFailed(msg.sender, balance);
    }

    // View functions with batch processing
    function getNFTsForAddress(address user, uint256 startIndex, uint256 batchSize) 
        public 
        view 
        returns (uint256[] memory) 
    {
        uint256 balance = MOONSHOTBOT_CONTRACT.balanceOf(user);
        if (startIndex >= balance) revert BatchSizeError("Start index out of bounds");
        if (batchSize > MAX_BATCH_SIZE) revert BatchSizeError("Batch size too large");
        
        uint256 endIndex = startIndex + batchSize;
        if (endIndex > balance) {
            endIndex = balance;
        }
        uint256 actualBatchSize = endIndex - startIndex;
        
        uint256[] memory tokens = new uint256[](actualBatchSize);
        for(uint256 i = 0; i < actualBatchSize; i++) {
            tokens[i] = MOONSHOTBOT_CONTRACT.tokenOfOwnerByIndex(user, startIndex + i);
        }
        
        return tokens;
    }

    function canNFTWithdraw(uint256 tokenId) public view returns (bool) {
        return block.timestamp >= lastWithdrawalTimeByNFT[tokenId] + TIME_INTERVAL;
    }

    function getRemainingTimeForNFT(uint256 tokenId) external view returns (uint256) {
        if (block.timestamp >= lastWithdrawalTimeByNFT[tokenId] + TIME_INTERVAL) {
            return 0;
        }
        return (lastWithdrawalTimeByNFT[tokenId] + TIME_INTERVAL) - block.timestamp;
    }

    function getRemainingTime() external view returns (uint256) {
        if (block.timestamp >= lastWithdrawalTime[msg.sender] + TIME_INTERVAL) {
            return 0;
        }
        return (lastWithdrawalTime[msg.sender] + TIME_INTERVAL) - block.timestamp;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Withdrawal functions with strict Checks-Effects-Interactions pattern
    function withdrawWithNFT(string memory note, uint256 tokenId) external 
        nonReentrant
        whenNotPaused 
        validNoteLength(note) 
    {
        if (address(this).balance < WITHDRAWAL_AMOUNT) {
            revert InsufficientBalance(address(this).balance, WITHDRAWAL_AMOUNT);
        }
        
        if (!canNFTWithdraw(tokenId)) {
            uint256 remainingTime = (lastWithdrawalTimeByNFT[tokenId] + TIME_INTERVAL) - block.timestamp;
            revert TimeIntervalError(remainingTime);
        }
        
        // Verify NFT ownership
        uint256 balance = MOONSHOTBOT_CONTRACT.balanceOf(msg.sender);
        bool ownsToken = false;
        for(uint256 i = 0; i < balance; i++) {
            if(MOONSHOTBOT_CONTRACT.tokenOfOwnerByIndex(msg.sender, i) == tokenId) {
                ownsToken = true;
                break;
            }
        }
        if (!ownsToken) revert NFTError("You don't own this NFT token");
        
        // Update state before transfer
        lastWithdrawalTimeByNFT[tokenId] = block.timestamp;
        
        // Emit event before transfer
        emit Withdrawal(msg.sender, WITHDRAWAL_AMOUNT, note, tokenId);
        
        // Transfer funds last
        (bool success, ) = payable(msg.sender).call{value: WITHDRAWAL_AMOUNT}("");
        if (!success) revert TransferFailed(msg.sender, WITHDRAWAL_AMOUNT);
    }

    function withdrawAsWhitelisted(string memory note) external 
        nonReentrant
        whenNotPaused 
        onlyAllowed 
        validNoteLength(note) 
    {
        if (address(this).balance < WITHDRAWAL_AMOUNT) {
            revert InsufficientBalance(address(this).balance, WITHDRAWAL_AMOUNT);
        }
        
        if (block.timestamp < lastWithdrawalTime[msg.sender] + TIME_INTERVAL) {
            uint256 remainingTime = (lastWithdrawalTime[msg.sender] + TIME_INTERVAL) - block.timestamp;
            revert TimeIntervalError(remainingTime);
        }
        
        // Update state before transfer
        lastWithdrawalTime[msg.sender] = block.timestamp;
        
        // Emit event before transfer
        emit Withdrawal(msg.sender, WITHDRAWAL_AMOUNT, note, 0);
        
        // Transfer funds last
        (bool success, ) = payable(msg.sender).call{value: WITHDRAWAL_AMOUNT}("");
        if (!success) revert TransferFailed(msg.sender, WITHDRAWAL_AMOUNT);
    }

    // Receive and fallback functions
    receive() external payable {}
    fallback() external payable {}
}
