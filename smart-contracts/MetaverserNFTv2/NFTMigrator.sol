
//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "./MetaverserNFTv2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMarketplaceAssets {
    struct MainAssetsNew {
        uint256 tokenId;
        string assetId;
        address owner;
        string asset_name;
        uint256 asset_type;
        uint256 price;
        bool saleable;
        uint256 sellType;
    }
    function getFullDataByTokenIdNew( uint256 _tokenId ) external view returns (MainAssetsNew memory);
}

interface IMetaverserNFT {
    function burnNFT(uint256 tokenId) external;
}

contract NFTMigrator is Ownable {
    address public migrationHelper;
    address public royaltyReceiver;
    uint96 public feeNumerator;
    uint256[] public migratedTokenIds;
    uint256[] public skippedTokenIds;

    MetaverserNFTv2 public newNFT;
    IMetaverserNFT public oldNFT;
    IMarketplaceAssets public marketplaceAssets;


    mapping(uint256 => bool) public migrated;
    mapping(uint256 => bool) public burned;
    mapping(address => bool) public isHolder;
    IMarketplaceAssets.MainAssetsNew[] public migratedTokenData;

    constructor(
        address _newNFT,
        address _oldNFT,
        address _marketplaceAssets,
        address _royaltyReceiver,
        uint96 _feeNumerator
    )  Ownable(msg.sender) {
        newNFT = MetaverserNFTv2(_newNFT);
        oldNFT = IMetaverserNFT(_oldNFT);
        marketplaceAssets = IMarketplaceAssets(_marketplaceAssets) ;
        royaltyReceiver = _royaltyReceiver;
        feeNumerator = _feeNumerator;
    }

    function _migrate(
        IMarketplaceAssets.MainAssetsNew memory _tokenData
    ) internal {
        require(!migrated[_tokenData.tokenId], "Migrator: already migrated");
        require(
            _tokenData.owner != address(0),
            "Migrator: mint to zero address"
        );

        newNFT.mint(
            _tokenData.owner,
            _tokenData.tokenId,
            royaltyReceiver,
            feeNumerator
        );

        migrated[_tokenData.tokenId] = true;
        migratedTokenIds.push(_tokenData.tokenId);
        migratedTokenData.push(_tokenData);

        if (!isHolder[_tokenData.owner]) {
            isHolder[_tokenData.owner] = true;
        }
    }

    function migrateByRanges(
        uint256 fromTokenId,
        uint256 toTokenId
    ) external onlyOwner {
        uint256[] memory tokenIds = new uint256[](toTokenId - fromTokenId + 1);
        for (uint256 i = 0; i <= toTokenId - fromTokenId; i++) {
            tokenIds[i] = fromTokenId + i;
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            IMarketplaceAssets.MainAssetsNew
                memory tokenData = getTokenDataById(tokenIds[i]);

            if (tokenData.owner != address(0)) {
                _migrate(tokenData);
            } else {
                skippedTokenIds.push(tokenIds[i]);
            }
        }
    }

    function migrateByIds(uint256[] memory tokenIds) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IMarketplaceAssets.MainAssetsNew
                memory tokenData = getTokenDataById(tokenIds[i]);

            if (tokenData.owner != address(0)) {
                _migrate(tokenData);
            } else {
                skippedTokenIds.push(tokenIds[i]);
            }
        }
    }

    function _burnMigrated(uint256 _id) internal {
        require(migrated[_id], "Migrator: not migrated");
        require(!burned[_id], "Migrator: already burned");
        if (!burned[_id]) {
            oldNFT.burnNFT(_id);
            burned[_id] = true;
        }
    }

    function burnMigratedTokens() external onlyOwner {
        for (uint256 i = 0; i < migratedTokenIds.length; i++) {
            if (!burned[migratedTokenIds[i]]) {
                _burnMigrated(migratedTokenIds[i]);
            }
        }
    }

    function burnMigratedTokensbyIds(
        uint256[] memory tokenIds
    ) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burnMigrated(tokenIds[i]);
        }
    }

    function burnMigratedTokensByRanges(
        uint256 fromTokenId,
        uint256 toTokenId
    ) external onlyOwner {
        uint256[] memory tokenIds = new uint256[](toTokenId - fromTokenId + 1);

        for (uint256 i = 0; i <= toTokenId - fromTokenId; i++) {
            tokenIds[i] = fromTokenId + i;
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burnMigrated(tokenIds[i]);
        }
    }

    function getMigratedTokenIds() external view returns (uint256[] memory) {
        return migratedTokenIds;
    }

    function getMigratedTokenDataById(
        uint256 _tokenId
    ) external view returns (IMarketplaceAssets.MainAssetsNew memory) {
        return migratedTokenData[_tokenId];
    }

    function getHolders(
        uint256 from,
        uint256 to
    ) external view returns (address[] memory) {
        address[] memory holders = new address[](to - from + 1);
        for (uint256 i = 0; i < to - from; i++) {
            holders[i] = migratedTokenData[from + i].owner;
        }
        return holders;
    }

    function getHoldersCount() external view returns (uint256) {
        return migratedTokenData.length;
    }

    //MigrateHelper

    function getTokenDataById(
        uint256 _tokenId
    ) public view returns (IMarketplaceAssets.MainAssetsNew memory) {
        return marketplaceAssets.getFullDataByTokenIdNew(_tokenId);
    }

    function getAllTokensDataByRanges(
        uint256 _from,
        uint256 _to
    ) public view returns (IMarketplaceAssets.MainAssetsNew[] memory) {
        IMarketplaceAssets.MainAssetsNew[]
            memory tokensData = new IMarketplaceAssets.MainAssetsNew[](
                _to - _from
            );
        for (uint256 i = _from; i < _to; i++) {
            tokensData[i - _from] = getTokenDataById(i);
        }
        return tokensData;
    }

    function getAllTokensData(
        uint256 _lenght
    ) public view returns (IMarketplaceAssets.MainAssetsNew[] memory) {
        return getAllTokensDataByRanges(0, _lenght);
    }

}