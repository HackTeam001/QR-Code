// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract QrCode {
    event ManufacturerAdded(address indexed manufacturer);
    event RetailerAdded(string retailer);
    event RetailerRemoved(uint256 indexed retailerID);

    event PasswordChanged(address indexed admin);
    event ownershipTransferred(address indexed newAdmin);

    event ItemAdded_M(uint256 indexed id);
    event ItemDetailsUpdated_M(
        uint256 indexed id,
        string itemName,
        string description
    );
    event ItemRecorded_M(uint256 indexed id);

    event qrHashStored(uint indexed timestamp);
    event qrHashDeleted(uint256 _blockId);

    struct Manufacturer {
        address manufacturer;
        string name;
        string location;
        string email;
        string phoneNumber;
        bytes32 password;
        bool isSignedUp;
    }

    struct Retailer {
        uint256 retailerID;
        string name;
        string location;
        string email;
        string phoneNumber;
    }

    struct ItemDetails {
        string itemName;
        string description;
    }

    //@dev create system account structure
    struct SystemOwner {
        address sysOwner;
        bytes32 password /*audit*/;
        bool isLogin;
    }

    address private owner;
    SystemOwner private sysowner;

    uint256 public s_retailerID;

    mapping(address => SystemOwner) private sysOwnerMap;

    mapping(address => Manufacturer) public manufacturerDetails;
    mapping(address => mapping(uint => Retailer))
        public manufacturerToRetailerDetails;
    mapping(string => Retailer) public retailerDetails;

    //STORING
    mapping(address => mapping(uint256 => string))
        private qrHashMapByManufacturer; // stored by manufacturer when generating hash + id

    uint256[] private manufacturerIDHashArr; //scanned by only manufacturer
    mapping(uint => bool) private storedIDs; //just stored

    //MATCHING
    mapping(string => uint256) public matchHashToId; //used by users when scanning

    mapping(string => bool) public matchedItems; //matched hash to items

    mapping(uint256 => ItemDetails) public itemDetails;

    constructor() {
        owner = msg.sender;
        sysowner = SystemOwner(owner, keccak256(abi.encode(("admin"))), false);
        sysOwnerMap[owner] = sysowner;
    }

    modifier onlySysOwner() {
        require(
            msg.sender == owner,
            "Only system owner can perform this action"
        );
        require(
            msg.sender != address(0),
            "Only system owner can perform this action"
        );
        _;
    }

    modifier onlyManufacturer() {
        require(
            manufacturerDetails[msg.sender].isSignedUp,
            "Only manufacturer can add retailer details"
        );
        require(
            msg.sender != address(0),
            "Only manufacturer can perform this action"
        );
        _;
    }

    /*@dev System Owner functions*/
    function loginSysOwner(
        bytes32 _password
    ) external onlySysOwner returns (bool) {
        require(
            sysOwnerMap[msg.sender].password ==
                keccak256(abi.encode(_password)),
            "Invalid password of account address"
        );
        sysOwnerMap[msg.sender].isLogin = true;
        return true;
    }

    function changePassword(
        bytes32 oldPassword,
        bytes32 _newPassword
    ) external onlySysOwner {
        require(
            sysOwnerMap[msg.sender].password ==
                keccak256(abi.encode(oldPassword)),
            "Invalid old password"
        );
        require(_newPassword.length > 0, "Password should not be empty");
        require(
            sysOwnerMap[msg.sender].password !=
                keccak256(abi.encode(_newPassword)),
            "Invalid new password"
        );
        require(sysOwnerMap[msg.sender].isLogin == true, "Not logged in");

        emit PasswordChanged(msg.sender);
        sysOwnerMap[msg.sender].password = _newPassword;
    }

    function transferOwnership(address _address) external onlySysOwner {
        delete sysOwnerMap[owner];
        emit ownershipTransferred(_address);
        owner = _address;
        sysOwnerMap[owner];
    }

    /*@dev Manufacturer functions*/
    function signUp(
        string memory _manfName,
        string memory _location,
        string memory _email,
        string memory _phoneNumber,
        bytes32 _password
    ) external {
        require(msg.sender != address(0), "Address not valid");
        require(msg.sender != owner, "Address shouldn't be system owner");
        require(
            manufacturerDetails[msg.sender].isSignedUp,
            "Manufacturer is already registered"
        );
        require(
            bytes(_manfName).length > 0,
            "Manufacturer name cannot be empty"
        );
        require(bytes(_location).length > 0, "Location name cannot be empty");
        require(bytes(_email).length > 0, "Email address cannot be empty");
        require(bytes(_phoneNumber).length > 0, "Phone number cannot be empty");
        require(_password.length > 0, "Email address cannot be empty");

        // Generate a salt (you can use a random number or a unique value)
        bytes32 salt = bytes32(
            uint256(
                keccak256(abi.encodePacked(block.timestamp, block.prevrandao))
            )
        );

        // Hash the password with the salt
        bytes32 passwordHash = keccak256(abi.encode(_password, salt));

        emit ManufacturerAdded(msg.sender);
        manufacturerDetails[msg.sender] = Manufacturer(
            msg.sender,
            _manfName,
            _location,
            _email,
            _phoneNumber,
            passwordHash,
            true
        );
    }

    //manufacturer only can add their retailers
    function addRetailerInfo(
        string memory _name,
        string memory _location,
        string memory _email,
        string memory _phoneNumber
    ) external onlyManufacturer {
        require(bytes(_name).length > 0, "Manufacturer name cannot be empty");
        require(bytes(_location).length > 0, "Location name cannot be empty");
        require(bytes(_email).length > 0, "Email address cannot be empty");
        require(bytes(_phoneNumber).length > 0, "Phone number cannot be empty");

        emit RetailerAdded(_name);
        s_retailerID++;
        manufacturerToRetailerDetails[msg.sender][s_retailerID] = Retailer(
            s_retailerID,
            _name,
            _location,
            _email,
            _phoneNumber
        );
        retailerDetails[_name] = manufacturerToRetailerDetails[msg.sender][
            s_retailerID
        ];
    }

    //only manufacturer can delete retailer
    function removeRetailer(uint256 _retailerID) external onlyManufacturer {
        require(
            manufacturerToRetailerDetails[msg.sender][_retailerID].retailerID ==
                _retailerID,
            "Retailer not found"
        );
        emit RetailerRemoved(_retailerID);
        delete manufacturerToRetailerDetails[msg.sender][_retailerID];
        delete retailerDetails[
            manufacturerToRetailerDetails[msg.sender][_retailerID].name
        ];
    }

    function storeQrHash(string memory _qrHash) external onlyManufacturer {
        uint256 timestamp = block.timestamp;
        emit qrHashStored(timestamp);
        qrHashMapByManufacturer[msg.sender][timestamp] = _qrHash;
        manufacturerIDHashArr.push(timestamp);
        storedIDs[timestamp] = true;
    }

    function deleteQrHash(uint _blockId) external onlyManufacturer {
        emit qrHashDeleted(_blockId);
        delete qrHashMapByManufacturer[msg.sender][_blockId];
        delete manufacturerIDHashArr[_blockId];
        delete storedIDs[_blockId];
    }

    //@dev returns qrcodeHash array to the manufacturer frontend
    function getManfItemIDList()
        external
        view
        onlyManufacturer
        returns (uint256[] memory)
    {
        return manufacturerIDHashArr;
    }

    //@dev !! views qrcodeHash and ID one by one. Used when manf wants to match stored ids & hashes to every item
    function getQrHashAndID()
        private
        view
        onlyManufacturer
        returns (string memory _qrHash, uint256 _blockId)
    {
        _qrHash = qrHashMapByManufacturer[msg.sender][_blockId];

        return (_qrHash, _blockId); //used at addItemDetails
    }

    /*@dev matches the stored hashes to each item & returns a bool for evidence */
    function addItemDetails(
        string memory _qrHash,
        uint256 _blockId,
        string memory _itemName,
        string memory _description
    ) external onlyManufacturer {
        require(
            compareStrings(
                qrHashMapByManufacturer[msg.sender][_blockId],
                _qrHash
            ),
            "Hash isn't stored"
        );
        require(storedIDs[_blockId] == true, "ID isn't stored");
        require(bytes(_itemName).length > 0, "Item name cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");

        emit ItemAdded_M(_blockId);
        emit ItemDetailsUpdated_M(_blockId, _itemName, _description);
        emit ItemRecorded_M(_blockId);

        matchHashToId[_qrHash] = _blockId; //update by matching
        matchedItems[_qrHash] = true;

        itemDetails[_blockId] = ItemDetails(_itemName, _description);
    }

    //used by users
    function scanItem(string memory _qrHash) external view returns (bool) {
        if (matchedItems[_qrHash]) {
            return true;
        } else {
            return false;
        }
    }

    //gives users more details of an item after scanning
    function moreDetailsForScannedItem(
        string memory _qrHash
    ) external view returns (ItemDetails memory) {
        uint id = matchHashToId[_qrHash];
        return itemDetails[id];
    }

    // Cannot directly compare strings in Solidity
    // This function hashes the 2 strings and then compares the 2 hashes
    function compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}
