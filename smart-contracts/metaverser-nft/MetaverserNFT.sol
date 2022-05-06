// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IMarketplaceAssets.sol" ;

contract MetaverserNFT is IMarketplaceAssets,ERC721URIStorage,ERC721Enumerable,Ownable,ERC721Holder {
    using Counters for Counters.Counter;
    //tokenid genereator
    Counters.Counter public TokenIdCounter; 
    //tokenid => fulldata
    mapping(uint256 => MainAssets )  public GameAssets; 
    //Contract or wallet can transfer data 
    mapping(address => bool) private accessListAddress;
    //History of Transaction
    mapping(uint256 => History[] ) HistoryTransactions ; 
    string[] assetTypes;

    modifier onlyAccessable(){
        require(accessListAddress[msg.sender] , "NFT: You are not access this method,Use `setAccessListAddress` method");
        _;
    }
    constructor() ERC721("Metaverser Assets", "MASSET") { 
        accessListAddress[msg.sender] = true;
        setAssetName(0,'Class_C_-_10x15.5m');

    }
    //override function
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
        HistoryTransactions[tokenId].push(History(tokenId,from,to,block.timestamp)); 

    }
    //limit transfer
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override onlyAccessable {
        super.safeTransferFrom(from, to, tokenId);
    }
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override onlyAccessable{
        super.safeTransferFrom(from, to, tokenId,_data);
    }
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override onlyAccessable{
        super.transferFrom(from, to, tokenId );
    }

    //Create Token just by contracts
     function createToken(address owner,  string memory _assetId,string memory _assetName,uint256 _assetType,string memory _tokenURI) public onlyAccessable returns (uint) {

        //require(isContract(msg.sender),"NFT: Only Contract Can do it");

        require(!getExistsAssetId(_assetId) , 'AssetId exist');

        TokenIdCounter.increment();

        uint256 tokenId = TokenIdCounter.current();
        _mint(owner, tokenId);
        _setTokenURI(tokenId, _tokenURI );


        GameAssets[tokenId]=MainAssets(tokenId,_assetId,owner,_assetName,_assetType,0,false,_tokenURI);
        emit createTokenEvent(owner, msg.sender,tokenId, _assetId,_assetName,_assetType,_tokenURI) ;
        return tokenId;
    }
    //override main interface
    function _burn( uint256 tokenId) internal override(ERC721URIStorage , ERC721) {
        //require(ownerOf(tokenId) == owner, "ERC721: burn of token that is not own" );
        super._burn(tokenId);
    }
    
     function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage,ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    //helper

    function burnNFT( uint256 tokenId) public onlyAccessable{
        //require(ownerOf(tokenId) == owner, "ERC721: burn of token that is not own" );
        GameAssets[tokenId] = MainAssets(0,'',address(0),'',0,0,false,'');

        _burn(tokenId );
    }
    //getter

    function getGameAssetByTokenId(uint256 tokenId) public view returns(MainAssets memory){
        return GameAssets[tokenId];
    }

    function getHistoryByToken(uint256 tokenId) public view returns(History[] memory){
        return HistoryTransactions[tokenId];
    }
    
    function getAssetName(uint256 index) public view returns(string memory){
        return assetTypes[index];
    }
    function getExistsAssetId(string memory _assetId) public view returns (bool){
        bool result = false;
        for(uint256 i=1;i<= super.totalSupply() ; i++) {
            if(  keccak256(bytes( GameAssets[i].assetId) )  == keccak256( bytes(_assetId) )  ){
                result =  true;
            }
        }
        return result;
    }

    //setter 
    function setAssetName(uint256 index,string memory _name) public  onlyOwner{
        if(index == 0) {
            assetTypes.push(_name);
        }else{
            assetTypes[index] = _name;
        }
        
        emit setAssetNameEvent(msg.sender,index, _name);

    }
    function setAccessListAddress(address _addr, bool act) public onlyOwner {
        accessListAddress[_addr] = act;
        emit setAccessListAddressEvent(msg.sender,_addr,act);
    }
    function setTokenOwner(uint256 tokenId,address newOwner) public  onlyAccessable{
        //just for emergency use
        require(ownerOf(tokenId) == newOwner , "NFT: new Owner is not correct in main nft contract; Use ownerOf Method for get correct owner" );
        GameAssets[tokenId].owner = newOwner;
        //emit event in nft contract
        //emit setTokenOwnerEvent(msg.sender,tokenId, newOwner);
    }
    function setTokenName(uint256 tokenId,string memory _name) public onlyAccessable {
        GameAssets[tokenId].asset_name = _name;
        emit setTokenNameEvent(msg.sender,tokenId,_name);
    }
    function setTokenAssetType(uint256 tokenId,uint256 _assetType) public onlyAccessable{
        GameAssets[tokenId].asset_type = _assetType;
        emit setTokenAssetTypeEvent(msg.sender,tokenId,_assetType);
    }
    function setTokenSeleable(uint256 tokenId , bool _saleable) public onlyAccessable {
        require(ownerOf(tokenId) == msg.sender , "NFT: Caller is not the token owner" );

        //onlyOwner when asset added to market 
        GameAssets[tokenId].saleable = _saleable;
    }
    function setTokenPrice(uint256 tokenId , uint256 price) public onlyAccessable {
        require(ownerOf(tokenId) == msg.sender , "NFT: Caller is not the token owner" );
        //onlyOwner when asset added to market 
        GameAssets[tokenId].price = price;
    }

    function setTokenURI(uint256 tokenId,string memory _tokenURI) public onlyAccessable{
        GameAssets[tokenId].uri = _tokenURI;
        _setTokenURI(tokenId, _tokenURI);
        emit setTokenURIEvent(msg.sender,tokenId,_tokenURI);
    }

}


