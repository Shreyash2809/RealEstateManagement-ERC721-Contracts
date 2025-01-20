// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RealEstateMarketplace is ERC721URIStorage, Ownable {

    struct Property {
        uint256 tokenId;
        string location;
        uint256 price;
        address currentOwner;
        bool forSale;
    }

    struct Escrow {
        uint256 tokenId;
        address buyer;
        uint256 price;
        bool isCompleted;
    }

    uint256 public tokenCounter;
    mapping(uint256 => Property) public properties;
    mapping(uint256 => Escrow) public escrows;

    event PropertyListed(uint256 indexed tokenId, address indexed owner, uint256 price);
    event PropertySold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event EscrowCreated(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event EscrowCompleted(uint256 indexed tokenId);

    constructor() ERC721("RealEstateToken", "RET") Ownable(msg.sender) {
        tokenCounter = 0;
    }

    // Mint a new property token
    function mintProperty(string memory location, uint256 price, string memory tokenURI) public onlyOwner {
        uint256 newTokenId = tokenCounter;
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        properties[newTokenId] = Property({
            tokenId: newTokenId,
            location: location,
            price: price,
            currentOwner: msg.sender,
            forSale: false
        });

        tokenCounter++;
    }

    // List a property for sale
    function listProperty(uint256 tokenId, uint256 price) public {
        require(ownerOf(tokenId) == msg.sender, "Only the owner can list this property.");
        require(price > 0, "Price must be greater than zero.");

        properties[tokenId].price = price;
        properties[tokenId].forSale = true;

        emit PropertyListed(tokenId, msg.sender, price);
    }

    // Buy a property
    function buyProperty(uint256 tokenId) public payable {
        Property storage property = properties[tokenId];
        require(property.forSale, "Property is not for sale.");
        require(msg.value == property.price, "Incorrect payment amount.");

        address seller = property.currentOwner;
        property.currentOwner = msg.sender;
        property.forSale = false;

        _transfer(seller, msg.sender, tokenId);
        payable(seller).transfer(msg.value);

        emit PropertySold(tokenId, msg.sender, property.price);
    }

    // Create an escrow for property purchase
    function createEscrow(uint256 tokenId) public payable {
        Property storage property = properties[tokenId];
        require(property.forSale, "Property is not for sale.");
        require(msg.value == property.price, "Incorrect escrow amount.");

        escrows[tokenId] = Escrow({
            tokenId: tokenId,
            buyer: msg.sender,
            price: msg.value,
            isCompleted: false
        });

        emit EscrowCreated(tokenId, msg.sender, msg.value);
    }

    // Complete the escrow and transfer ownership
    function completeEscrow(uint256 tokenId) public {
        Escrow storage escrow = escrows[tokenId];
        require(!escrow.isCompleted, "Escrow already completed.");
        require(escrow.buyer == msg.sender, "Only the buyer can complete the escrow.");

        Property storage property = properties[tokenId];
        address seller = property.currentOwner;

        property.currentOwner = escrow.buyer;
        property.forSale = false;
        escrow.isCompleted = true;

        _transfer(seller, escrow.buyer, tokenId);
        payable(seller).transfer(escrow.price);

        emit EscrowCompleted(tokenId);
    }

    // Fetch property details
    function getProperty(uint256 tokenId) public view returns (Property memory) {
        return properties[tokenId];
    }
}
