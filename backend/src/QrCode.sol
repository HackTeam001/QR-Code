// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract QrCode {
    event ManufacturerAdded(address indexed manufacturer);
    event RetailerAdded(
        address indexed manufacturer,
        address indexed _retailer
    );
    event ItemStored(uint256 indexed _batchNumber, uint256 indexed _productId);
    event ItemDeleted(uint256 indexed _productId);
    event ItemSold(uint256 indexed _productId);
    event BatchTrackedToRetailer(uint256 indexed batchNumber);

    address public immutable i_systemOwner;

    uint256 public currentTime;

    mapping(address manufacturer => bool) public verifiedManufacturer;

    mapping(address manufacturer => address retailer)
        public manufacturerToRetailers;
    mapping(address manufacturer => mapping(address retailer => bool))
        public verifiedRetailer;
    mapping(address retailer => bool) public isRetailer;

    mapping(uint256 batchNumber => address manufacturer)
        public batchNumberToManufacturer;
    mapping(uint256 batchNumber => address retailer)
        public batchNumberToRetailer;

    mapping(uint256 productId => address manufacturer)
        public productIDsToManufacturer;
    mapping(uint256 productId => uint256 batchNumber)
        public productIDsToBatchNumbers;

    mapping(uint256 productId => bool) public isStored;
    mapping(uint256 batchNumber => bool) public batchIsStored; //large manufacturers
    mapping(uint256 productId => bool) public itemSold;

    constructor(address _owner) {
        i_systemOwner = _owner;
    }

    function addManufacturer(address _manufacturer) external {
        require(msg.sender == i_systemOwner, "Action only taken by owner");
        require(_manufacturer != address(0), "Invalid address");
        emit ManufacturerAdded(_manufacturer);
        verifiedManufacturer[_manufacturer] = true;
    }

    function addRetailer(address _retailer) external {
        require(
            verifiedManufacturer[msg.sender] == true,
            "Action only taken by a verified manufacturer"
        );
        require(_retailer != address(0), "Invalid address");

        emit RetailerAdded(msg.sender, _retailer);
        manufacturerToRetailers[msg.sender] = _retailer;
        verifiedRetailer[msg.sender][_retailer] = true;
        isRetailer[_retailer] = true;
    }

    //by small-scale manufacturers
    function storeItem(
        uint256 _batchNumber,
        uint256 _productId
    ) external returns (uint256) {
        require(
            verifiedManufacturer[msg.sender] == true,
            "Action only taken by a verified manufacturer"
        );
        require(!isStored[_productId], "Product ID is already stored");

        emit ItemStored(_batchNumber, _productId);
        batchNumberToManufacturer[_batchNumber] = msg.sender;
        productIDsToBatchNumbers[_productId] = _batchNumber;
        productIDsToManufacturer[_productId] = msg.sender;
        isStored[_productId] = true;
        itemSold[_productId] = false;
        currentTime = block.timestamp;
        return currentTime;
    }

    //by large scale manufacturers
    function storeItemLargeManufacturers(
        uint256 _batchNumber
    ) external returns (uint256) {
        require(
            verifiedManufacturer[msg.sender] == true,
            "Action only taken by a verified manufacturer"
        );
        require(!batchIsStored[_batchNumber], "Batch number is already stored");
        batchNumberToManufacturer[_batchNumber] = msg.sender;
        currentTime = block.timestamp;
        return currentTime;
    }

    function trackBatchesSentToRetailers(
        uint256 _batchNumber,
        address _retailer
    ) external {
        emit BatchTrackedToRetailer(_batchNumber);
        batchNumberToRetailer[_batchNumber] = _retailer;
    }

    function deleteStoredItem(uint256 _productId) external returns (uint256) {
        require(
            verifiedManufacturer[msg.sender] == true,
            "Action only taken by a verified manufacturer"
        );
        emit ItemDeleted(_productId);
        delete productIDsToBatchNumbers[_productId];
        isStored[_productId] = false;
        currentTime = block.timestamp;
        return currentTime;
    }

    //Return with frontend Item Details (Description, manufacturer)
    function scanItem(uint256 _productId) external view returns (bool) {
        if (isStored[_productId] == true) {
            return true;
        }
        return false;
    }

    function itemIsSold(uint256 _productId) external returns (uint256) {
        require(
            isRetailer[msg.sender] == true,
            "Action only taken by a verified retailer"
        );

        emit ItemSold(_productId);
        currentTime = block.timestamp;
        itemSold[_productId] = true;
        return currentTime;
    }

    //GETTER FUNCTIONS
    function checkIfManufacturer(
        address _manufacturer
    ) external view returns (bool) {
        bool isManufacturer = verifiedManufacturer[_manufacturer];
        return isManufacturer;
    }

    function checkIfRetailer(address _retailer) external view returns (bool) {
        bool retailer = isRetailer[_retailer];
        return retailer;
    }

    function getBatchNumberBasedOnProductId(
        uint256 _productID
    ) external view returns (uint256) {
        uint256 batch = productIDsToBatchNumbers[_productID];
        return batch;
    }

    function getManufacturerAddressBasedOnProductId(
        uint256 _productID
    ) external view returns (address) {
        address manufacturer = productIDsToManufacturer[_productID];
        return manufacturer;
    }

    function getManufacturerAddressBasedOnBatchNumber(
        uint256 _batchNumber
    ) external view returns (address) {
        address manufacturer = batchNumberToManufacturer[_batchNumber];
        return manufacturer;
    }

    function checkIfItemIsStored(
        uint256 _productID
    ) external view returns (bool) {
        bool stored = isStored[_productID];
        return stored;
    }

    function checkIfItemIsSold(
        uint256 _productID
    ) external view returns (bool) {
        bool sold = itemSold[_productID];
        return sold;
    }
}
