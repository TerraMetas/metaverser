//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MetaverserNFTv2 is ERC721Royalty, Ownable {
    constructor(
        uint96 defaultRoyaltyFee_,
        address royalityFeeRecipient_
    ) ERC721("Metaverser Assets", "MASSETV2") Ownable(msg.sender) {
        _setDefaultRoyalty(royalityFeeRecipient_, defaultRoyaltyFee_);
        isAdmin[msg.sender] = true;
    }

    mapping(address => bool) public isAdmin;
    uint256 public lastTokenId;

    modifier onlyAdmins() {
        require(isAdmin[msg.sender], "Only admins can execute this function");
        _;
    }

    function mint(
        address to,
        uint256 tokenId,
        address royaltyReceiver,
        uint96 feeNumerator
    ) public onlyAdmins {
        uint256 _tokenId = tokenId;
        if (_tokenId == 0) {
            lastTokenId++;
            _tokenId = lastTokenId;
        } else if (_tokenId > lastTokenId) {
            lastTokenId = _tokenId;
        }

        _mint(to, tokenId);
        _setTokenRoyalty(tokenId, royaltyReceiver, feeNumerator);
    }

    function batchMint(
        address to,
        uint256[] memory tokenIds,
        address royaltyReceiver,
        uint96 feeNumerator
    ) public onlyAdmins {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _mint(to, tokenIds[i]);
            lastTokenId = tokenIds[i];
            _setTokenRoyalty(tokenIds[i], royaltyReceiver, feeNumerator);
        }
    }

    function burn(uint256 tokenId) public virtual {
        require(
            _requireOwned(tokenId) == msg.sender,
            "ERC721: caller is not token owner"
        );
        _burn(tokenId);
    }

    function setAdmin(address _address, bool _isAdmin) external onlyOwner {
        isAdmin[_address] = _isAdmin;
    }

    function setDefaultRoyalty(
        address royaltyReceiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(royaltyReceiver, feeNumerator);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://lands.metaverser.me/lands.v2/";
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(
                    abi.encodePacked(
                        baseURI,
                        Strings.toString(tokenId),
                        ".json"
                    )
                )
                : "";
    }
}