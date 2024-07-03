// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MetaverserMarketplaceV2 is ReentrancyGuard {
    constructor(address _MTVT, address _NFT) {
        // Open the marketplace
        isClosed = false;

        // Set MTVT address
        MTVT = _MTVT;

        // Set NFT address
        NFT = _NFT;

        // Add admins
        isAdmin[msg.sender] = true;
        emit AdminSet(msg.sender, true);

        // 0 index is used to represent null listing
        listings[0] = Listing(address(0), 0, 0, 0, false, 0);
        emit ListingCreated(0, address(0), 0, 0, 0);
    }

    // Structs

    struct Listing {
        address seller;
        uint256 listId;
        uint256 tokenId;
        uint256 price;
        bool active;
        uint256 expiryDate;
    }

    // Storage

    bool public isClosed;

    address public immutable MTVT;
    address public immutable NFT;

    mapping(uint256 => Listing) private listings;
    mapping(address => uint256[]) private sellerListings;
    mapping(uint256 => bool) private isListed;

    mapping(address => bool) private isAdmin;
    uint256 public nextListingId = 1;

    uint256 public totalRoyaltyAmount;
    mapping(address => uint256) royaltyAmounts;

    // Modifiers

    modifier onlyAdmin() {
        require(
            isAdmin[msg.sender],
            "Marketplace: Only admin can call this function"
        );
        _;
    }

    // External functions

    // Function to list a token for sale
    // @dev _expiryDate is optional (0 means no expiry date)
    function listForSale(
        uint256 _tokenId,
        uint256 _price,
        uint256 _expiryDate
    ) external {
        require(!isClosed, "Marketplace: Marketplace is closed");
        require(
            IERC721(NFT).ownerOf(_tokenId) == msg.sender,
            "Marketplace: You are not the owner"
        );
        require(
            IERC721(NFT).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(NFT).getApproved(_tokenId) == address(this),
            "Marketplace: Approve first"
        );
        require(
            _expiryDate >= block.timestamp || _expiryDate == 0,
            "Marketplace: Invalid expiry date"
        );
        require(!isListed[_tokenId], "Marketplace: Token already listed!");

        listings[nextListingId] = Listing(
            msg.sender,
            nextListingId,
            _tokenId,
            _price,
            true,
            (_expiryDate == 0 ? type(uint256).max : _expiryDate)
        );

        sellerListings[msg.sender].push(nextListingId);
        isListed[_tokenId] = true;

        emit ListingCreated(
            nextListingId,
            msg.sender,
            _price,
            _expiryDate,
            _tokenId
        );

        nextListingId++;
    }

    // Function to buy a listed token
    // @dev prior approval is required for the marketplace contract to spend MTVT on behalf of the buyer
    // @dev respects erc2981 royalty standard
    function buy(uint256 _listingId) external nonReentrant {
        require(!isClosed, "Marketplace: Marketplace is closed");
        Listing storage listing = listings[_listingId];
        require(
            listing.expiryDate > block.timestamp,
            "Marketplace: Listing expired"
        );
        require(_isValid(_listingId), "Marketplace: Invalid listing");
        require(
            listing.price <= IERC20(MTVT).balanceOf(msg.sender),
            "Marketplace: Insufficient funds"
        );

        IERC721(NFT).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        (address royaltyReceiver, uint256 royaltyAmount) = IERC2981(NFT)
            .royaltyInfo(listing.tokenId, listing.price);

        if (royaltyReceiver != address(0) && royaltyAmount > 0) {
            totalRoyaltyAmount += royaltyAmount;
            royaltyAmounts[royaltyReceiver] += royaltyAmount;
            IERC20(MTVT).transferFrom(
                msg.sender,
                royaltyReceiver,
                royaltyAmount
            );
            IERC20(MTVT).transferFrom(
                msg.sender,
                listing.seller,
                listing.price - royaltyAmount
            );
        } else {
            IERC20(MTVT).transferFrom(
                msg.sender,
                listing.seller,
                listing.price
            );
        }

        for (uint256 i = 0; i < sellerListings[listing.seller].length; i++) {
            if (sellerListings[listing.seller][i] == _listingId) {
                sellerListings[listing.seller][i] = sellerListings[
                    listing.seller
                ][sellerListings[listing.seller].length - 1];
                sellerListings[listing.seller].pop();
                break;
            }
        }

        listing.active = false;
        isListed[listing.tokenId] = false;

        emit ListingBought(
            _listingId,
            msg.sender,
            listing.seller,
            listing.price,
            listing.tokenId
        );
    }

    function deleteListing(uint256 _listingId) external nonReentrant {
        require(!isClosed, "Marketplace: Marketplace is closed");
        Listing storage listing = listings[_listingId];
        require(
            listing.seller == msg.sender,
            "Marketplace: You are not the seller"
        );
        listings[_listingId].active = false;

        for (uint256 i = 0; i < sellerListings[msg.sender].length; i++) {
            if (sellerListings[msg.sender][i] == _listingId) {
                sellerListings[msg.sender][i] = sellerListings[msg.sender][
                    sellerListings[msg.sender].length - 1
                ];
                sellerListings[msg.sender].pop();
                break;
            }
        }

        isListed[listing.tokenId] = false;

        emit ListingDeleted(_listingId);
    }

    function changeExpiryDate(
        uint256 _listingId,
        uint256 _newExpiryDate
    ) external {
        require(!isClosed, "Marketplace: Marketplace is closed");
        Listing storage listing = listings[_listingId];
        require(listing.seller == msg.sender, "Marketplace: Not your listing");
        require(
            _newExpiryDate >= block.timestamp,
            "Marketplace: Invalid new expiry date"
        );
        require(_isValid(_listingId), "Marketplace: Invalid listing");
        listing.expiryDate = _newExpiryDate;

        emit ExpiryDateChanged(_listingId, _newExpiryDate);
    }

    function changePrice(uint256 _listingId, uint256 _newPrice) external {
        require(!isClosed, "Marketplace: Marketplace is closed");
        Listing storage listing = listings[_listingId];
        require(listing.seller == msg.sender, "Marketplace: Not your listing");
        require(_isValid(_listingId), "Marketplace: Invalid listing");
        listing.price = _newPrice;

        emit PriceChanged(_listingId, _newPrice);
    }

    // Admin functions

    function setAdmin(address _admin, bool _isAdmin) external onlyAdmin {
        require(isAdmin[_admin] != _isAdmin, "Marketplace: Invalid input");
        isAdmin[_admin] = _isAdmin;

        emit AdminSet(_admin, _isAdmin);
    }

    function closeMarketplace() external onlyAdmin {
        require(!isClosed, "Marketplace: Marketplace is already closed");
        isClosed = true;
    }

    function openMarketplace() external onlyAdmin {
        require(isClosed, "Marketplace: Marketplace is already open");
        isClosed = false;
    }

    // View functions

    function getAllListings() external view returns (uint256[] memory) {
        uint256[] memory validListings = new uint256[](nextListingId - 1);
        uint256 validListingCount = 0;

        for (uint256 i = 1; i < nextListingId; i++) {
            if (_isValid(i)) {
                validListings[validListingCount] = i;
                validListingCount++;
            }
            if (gasleft() < 10000) {
                break;
            }
        }

        uint256[] memory result = new uint256[](validListingCount);
        for (uint256 i = 0; i < validListingCount; i++) {
            result[i] = validListings[i];
        }

        return result;
    }

    function getAllListingsBySeller(
        address _seller
    ) external view returns (Listing[] memory) {
        uint256[] memory validListings = new uint256[](
            sellerListings[_seller].length
        );
        uint256 validListingCount = 0;

        for (uint256 i = 0; i < sellerListings[_seller].length; i++) {
            uint256 listingId = sellerListings[_seller][i];
            if (_isValid(listingId)) {
                validListings[validListingCount] = listingId;
                validListingCount++;
            }
        }

        Listing[] memory result = new Listing[](validListingCount);
        for (uint256 i = 0; i < validListingCount; i++) {
            result[i] = _getListingById(validListings[i]);
        }

        return result;
    }

    function getListingByIds(
        uint256[] calldata _listingIds
    ) external view returns (Listing[] memory) {
        Listing[] memory result = new Listing[](_listingIds.length);

        for (uint256 i = 0; i < _listingIds.length; i++) {
            result[i] = _getListingById(_listingIds[i]);
        }

        return result;
    }

    function getListingByRanges(
        uint256 _from,
        uint256 _to
    ) external view returns (Listing[] memory) {
        Listing[] memory validListings = new Listing[](_to - _from + 1);
        uint256 validListingCount = 0;

        for (uint256 i = _from; i <= _to; i++) {
            if (_isValid(i)) {
                validListings[validListingCount] = _getListingById(i);
                validListingCount++;
            }
        }

        Listing[] memory result = new Listing[](validListingCount);

        for (uint256 i = 0; i < validListingCount; i++) {
            result[i] = validListings[i];
        }

        return result;
    }

    function getListingById(
        uint256 _listingId
    ) external view returns (Listing memory) {
        return _getListingById(_listingId);
    }

    function getRoyaltyAmount(
        address _receiver
    ) external view returns (uint256) {
        return royaltyAmounts[_receiver];
    }

    // Internal view functions

    function _getListingById(
        uint256 _listingId
    ) internal view returns (Listing memory) {
        Listing memory listing = listings[_listingId];
        return listing;
    }

    function _isValid(uint256 listingId) internal view returns (bool) {
        Listing memory listing = listings[listingId];
        IERC721 token = IERC721(NFT);

        return ((token.getApproved(listing.tokenId) == address(this) ||
            token.isApprovedForAll(listing.seller, address(this))) &&
            token.ownerOf(listing.tokenId) == listing.seller &&
            listing.active &&
            listing.expiryDate > block.timestamp);
    }

    // Events

    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        uint256 price,
        uint256 expiryDate,
        uint256 tokenId
    );

    event ListingDeleted(uint256 indexed listingId);

    event ListingBought(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 tokenId
    );

    event ExpiryDateChanged(uint256 indexed listingId, uint256 newExpiryDate);

    event PriceChanged(uint256 indexed listingId, uint256 newPrice);

    event AdminSet(address indexed admin, bool isAdmin);
}