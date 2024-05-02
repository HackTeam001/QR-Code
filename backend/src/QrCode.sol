// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract QrCode {
    event ManufacturerAdded(address indexed manufacturer);
    event RetailerAdded(
        address indexed manufacturer,
        address indexed _retailer
    );
    event ItemStored(uint256 indexed _batchNumber, uint256 indexed _productId);
    event DeletedItem(uint256 indexed _productId);
    event ItemSold(uint256 indexed _productId);

    address public immutable i_systemOwner;

    uint256 public currentTime;

    mapping(address manufacturer => bool) public verifiedManufacturer;
    mapping(address manufacturer => mapping(address retailer => bool))
        public manufacturerToRetailer;
    mapping(address retailer => bool) public isRetailer;

    mapping(uint256 batchNumber => address manufacturer)
        public batchNumberToManufacturer;
    mapping(uint256 productId => uint256 batchNumber)
        public productIDsToBatchNumbers;
    mapping(uint256 productId => bool) public isStored;
    mapping(uint256 productId => bool) public itemSold;

    constructor(address _owner) {
        i_systemOwner = _owner;
    }

    function addManufacturer(address manufacturer) external {
        require(msg.sender == i_systemOwner, "Action only taken by owner");
        emit ManufacturerAdded(manufacturer);
        verifiedManufacturer[manufacturer] = true;
    }

    function addRetailer(address _retailer) external {
        require(
            verifiedManufacturer[msg.sender] == true,
            "Action only taken by a verified manufacturer"
        );
        emit RetailerAdded(msg.sender, _retailer);
        manufacturerToRetailer[msg.sender][_retailer] = true;
        isRetailer[_retailer] = true;
    }

    function storeItem(uint256 _batchNumber, uint256 _productId) external {
        require(
            verifiedManufacturer[msg.sender] == true,
            "Action only taken by a verified manufacturer"
        );
        emit ItemStored(_batchNumber, _productId);
        currentTime = block.timestamp;
        batchNumberToManufacturer[_batchNumber] = msg.sender;
        productIDsToBatchNumbers[_productId] = _batchNumber;
        isStored[_productId] = true;
        itemSold[_productId] = false;
    }

    function deleteStoredItem(uint256 _productId) external {
        require(
            verifiedManufacturer[msg.sender] == true,
            "Action only taken by a verified manufacturer"
        );
        emit DeletedItem(_productId);
        currentTime = block.timestamp;
        delete productIDsToBatchNumbers[_productId];
        isStored[_productId] = false;
    }

    //return with frontend Item Details
    //not sure for the returns
    function scanItem(
        uint256 _productId
    ) public view returns (bool, uint256, address, bool) {
        if (isStored[_productId] == true) {
            uint256 batchNumber = productIDsToBatchNumbers[_productId];
            address manufacturer = batchNumberToManufacturer[batchNumber];
            bool item_sold = itemSold[_productId];
            return (true, batchNumber, manufacturer, item_sold);
        }
    }

    /* function itemIsSold(
        uint256 _productId
    ) external view returns (uint256, bool) {
        require(
            isRetailer[msg.sender] == true,
            "Action only taken by a verified retailer"
        );
    
            emit ItemSold(_productId);
            currentTime = block.timestamp;
            itemSold[_productId] = true;
            return currentTime;

    } */
}
