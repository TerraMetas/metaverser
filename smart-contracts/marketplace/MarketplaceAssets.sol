// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

 import "./MetaverserNFT.sol";
import "./interfaces/IMarketplaceAssets.sol" ;
contract MarketplaceAssets is IMarketplaceAssets,Ownable,ERC721Holder {
  
   address public nftContract  ;
   mapping(uint256 =>  MainAssets ) private MarketGameAssets; 
   bool PauseMarket;
   address taxAddress;
   uint16 taxPercent ;
   uint256 private totalSupply;
   modifier tokenOwnerAccess(uint256 tokenId){
       require(MarketGameAssets[tokenId].owner == msg.sender ,'You are not owner' );
       _;
   }
   
   modifier notPause() {
       require(!PauseMarket , "Market is paused");
       _;
   }
   
    constructor(address _nftContract)  {
        nftContract= _nftContract;
        PauseMarket = false;
        taxAddress = msg.sender;
        taxPercent = 5;
        totalSupply= MetaverserNFT(nftContract).totalSupply();
        //synctContractData();
    }
    function deposit() public payable {}
    function withdraw() public payable onlyOwner{
         payable(owner()).transfer( address(this).balance ) ;
    }
    //override function

    //override our interface
    function addNewAssets(address owner, string memory _assetName, string memory _assetId, uint256 _assetType,string memory _tokenURI) onlyOwner public returns(uint256){
        //require not exist
        uint256 newItemId = MetaverserNFT(nftContract).createToken(owner, _assetId,_assetName,_assetType,_tokenURI);
        MarketGameAssets[newItemId] = MetaverserNFT(nftContract).getGameAssetByTokenId(newItemId);
        totalSupply++;
        return newItemId;
    }
    // 
 
    function addBatchAssets(MainAssetsInput[] memory assets) onlyOwner public   {
        for(uint256 i=0;i<assets.length ; i++ ) {
            addNewAssets(owner(),assets[i].asset_name,assets[i].assetId,assets[i].asset_type,assets[i].uri);
        }
    }
    
    function replacementAssets(uint256[] memory tokenIds,string memory _assetName, string memory _assetId, uint256 _assetType,string memory _tokenURI) public onlyOwner returns(uint256)  {
        address oldOwner;

        for(uint256 i=0;i<tokenIds.length ; i++ ) {
            MetaverserNFT(nftContract).burnNFT( tokenIds[i]) ;
            oldOwner = MarketGameAssets[tokenIds[i]].owner;
        }
        
        
        uint256 newItem= addNewAssets(oldOwner , _assetName, _assetId, _assetType,_tokenURI);
         for(uint256 i=0;i<tokenIds.length ; i++ ) {
            MarketGameAssets[tokenIds[i]] = MainAssets(0,'',address(0),'',0,0,false,'');
        }
        //transferTokenByOwner(uint256 tokenId,address to)
        // MetaverserNFT(nftContract).approve( address(this) , newItem );
        // MetaverserNFT(nftContract).transferFrom( address(this) ,oldOwner , newItem);
        // //set token Onwer on GameAssets
        // MarketGameAssets[tokenId] = MainAssets(0,'',address(0),'',0,0,false,'');
        // MarketGameAssets[newItem].owner;
        // MetaverserNFT(nftContract).setTokenOwner(newItem ,oldOwner);

        return newItem ;

    }

    //write

    function buyAsset(uint256 tokenId,string memory _name) public payable  notPause {
        
        
        require(MarketGameAssets[tokenId].saleable  ,'Asset not for sale');
        require(getPrice(tokenId) > 0  ,'Asset Has not price');
        require(payable(MarketGameAssets[tokenId].owner) != address(0) ,'Zero address cannot buy');
       
        bool contractOwnerIsOwner = (MarketGameAssets[tokenId].owner == owner() );

        // require( getPayablePrice(tokenId) <= address(msg.sender).balance , 'Insufficient funds for this action');
        
        uint256 price = getPrice(tokenId);
        //royalty for market owner
        
        uint256 tax = ((price * taxPercent)  /100 );
        //deposit bnb to contract
        deposit();
        //transfer to token owner 
        payable(MarketGameAssets[tokenId].owner).transfer(price);

        //transfer royalty to contract owner 
        if(!contractOwnerIsOwner ) {
            payable(taxAddress).transfer(tax);
        }
        
        emit buyAssetEvent(msg.sender,MarketGameAssets[tokenId].owner,getPrice(tokenId), tokenId,price,tax);
        
        //setTokenSeleable can call when contract is owner
        //set seleable in GameAssets;
        MetaverserNFT(nftContract).setTokenSeleable(tokenId , false ); 
        MetaverserNFT(nftContract).setTokenName(tokenId , _name );

        MetaverserNFT(nftContract).transferFrom(address(this), msg.sender, tokenId);

        //set token Onwer on GameAssets
        MetaverserNFT(nftContract).setTokenOwner(tokenId , msg.sender );

        MarketGameAssets[tokenId].saleable = false;
        MarketGameAssets[tokenId].asset_name =_name;
        MarketGameAssets[tokenId].owner = msg.sender;
        

    }


    function synctContractData(uint256 _from, uint256 _to) public onlyOwner   {
        
        uint256 _totalSupply = MetaverserNFT(nftContract).totalSupply();
        if(_to >= _totalSupply ) {
            _to = _totalSupply;
        }

        for(uint256 i=_from;i<=_to ; i++) {
            MarketGameAssets[i] = MetaverserNFT(nftContract).getGameAssetByTokenId(i);
        }
        //change owner from old contract 

        emit synctContractDataEvent(msg.sender,nftContract,_from,_to) ;   

    }
    function transferToNewContract(address _newContract) public onlyOwner {
        //
        uint256 _to = totalSupply;

        for(uint256 i=1;i<=_to ; i++) {
            if(MetaverserNFT(nftContract).ownerOf(i) == address(this) ) {
                   MetaverserNFT(nftContract).transferFrom(address(this),_newContract,i); 
            } 
        }
        //change owner from old contract 

    }
    //notPause
    function addAssetToMarket(uint256 tokenId,  uint256 price) public tokenOwnerAccess(tokenId) notPause{

        //require(MarketGameAssets[tokenId].owner == msg.sender);
        require(tokenId > 0 , 'TokenId cannot be zero' ) ;
        require(price > 0 , 'Price cannot be zero' ) ;
        MetaverserNFT(nftContract).safeTransferFrom(msg.sender , address(this), tokenId);

        MarketGameAssets[tokenId].saleable= true ;
        MarketGameAssets[tokenId].price = price ;
        //setTokenSeleable and setTokenPrice can call when contract is owner
        //set seleable in GameAssets
        MetaverserNFT(nftContract).setTokenSeleable(tokenId , true ); 
        //set price in GameAssets
        MetaverserNFT(nftContract).setTokenPrice(tokenId , price ); 

        emit  addAssetToMarketEvent(msg.sender,tokenId,price);

    }

    function removeAssetFromMarket(uint256 tokenId) public tokenOwnerAccess(tokenId){
        require(!PauseMarket , "Market is paused by owner");
        //require(MarketGameAssets[tokenId].owner == msg.sender );
        //setTokenSeleable can call when contract is owner
        MetaverserNFT(nftContract).setTokenSeleable(tokenId , false ); 

        MetaverserNFT(nftContract).safeTransferFrom( address(this) ,msg.sender, tokenId);
        MarketGameAssets[tokenId].saleable= false ;
        //set seleable in GameAssets
        

        emit  removeAssetFromEvent(msg.sender,tokenId);

    }
    function addBatchAssetsToMarket(uint256[] memory tokenIds, uint256 price) onlyOwner public   {
        for(uint256 i=0;i<tokenIds.length ; i++ ) {
            addAssetToMarket(tokenIds[i],price);
        }
    }
    function transferToken(uint256 tokenId,address to) public payable tokenOwnerAccess(tokenId) notPause{

        require(getPrice(tokenId) > 0  ,'Asset Has not price');
        require(payable(MarketGameAssets[tokenId].owner) != address(0) ,'Zero address cannot buy');
        require(to != address(0) ,'Receiver cannot be zero address');
        
        
        //require(MarketGameAssets[tokenId].owner == msg.sender );
        uint256 price = getPrice(tokenId);
        //royalty for market owner
        uint256 royaltyPercent = 5;
        uint256 amountForOwner= (price * ( 100 - royaltyPercent) )/100 ;
        uint256  royalty = price - amountForOwner  ;
        
        require( royalty <= address(msg.sender).balance,'Insufficient funds for this action');

        deposit();

        payable( taxAddress ).transfer(royalty);

        MetaverserNFT(nftContract).safeTransferFrom(msg.sender , to, tokenId);

        MarketGameAssets[tokenId].owner = to ;

        MetaverserNFT(nftContract).setTokenOwner(tokenId, to);


    }
    function transferTokenByOwner(uint256 tokenId,address to) public onlyOwner tokenOwnerAccess(tokenId) {
        //require(MarketGameAssets[tokenId].owner == msg.sender );
        MetaverserNFT(nftContract).safeTransferFrom(msg.sender , to, tokenId);
        MetaverserNFT(nftContract).setTokenOwner(tokenId, to);
        MarketGameAssets[tokenId].owner = to ;

    }
    
    //setter
    function setPause(bool _pause) public onlyOwner {
        PauseMarket = _pause;
    }
    function setTaxAddress(address _address) public onlyOwner {
        taxAddress = _address;
    }

    
    function setTokenName(uint256 tokenId,string memory _name) public{
        require(MarketGameAssets[tokenId].owner == msg.sender , "You are not token owner") ;
        MarketGameAssets[tokenId].asset_name = _name;
        MetaverserNFT(nftContract).setTokenName(tokenId,_name);
        //emit event in nft contract
        //emit setTokenNameEvent(msg.sender,tokenId, _name);

    }
    function setTokenAssetType(uint256 tokenId,uint256 _assetType) public  onlyOwner{
        MarketGameAssets[tokenId].asset_type = _assetType;
        MetaverserNFT(nftContract).setTokenAssetType(tokenId,_assetType);
        emit setTokenAssetTypeEvent(msg.sender,tokenId, _assetType);
    }
    function setTokenOwner(uint256 tokenId,address newOwner) public  onlyOwner{
        //just for trace and debug (not use ) ;
        require(MetaverserNFT(nftContract).ownerOf(tokenId) == newOwner , "new Owner is not correct in main nft contract; Use ownerOf Method for get correct owner" );
        MarketGameAssets[tokenId].owner = newOwner;
        //emit event in nft contract
        //emit setTokenOwnerEvent(msg.sender,tokenId, newOwner);
    }
    function setTokenURI(uint256 tokenId,string memory newURI) public  onlyOwner{
        //just for trace and debug (not use ) ;
        MetaverserNFT(nftContract).setTokenURI(tokenId,newURI);
        MarketGameAssets[tokenId].uri = newURI;

    }

    function setNFTContract(address newNFTContract,uint256 _from ,uint256 _to) public onlyOwner {
        nftContract = newNFTContract;
        synctContractData(_from,_to);
    }

    //getter 

    function getSupplyByType(uint256 _type) public  view returns (uint256 ){
        uint256 counter=0;
        for(uint256 i=1;i<= totalSupply ; i++) {
            if(   MarketGameAssets[i].asset_type   == _type ){
                counter++;
                //assets.push(MarketGameAssets[i]);
            }
        }
        return counter;
    }
    function getSupplyByOwner(address _address) public  view returns (uint256 ){
        uint256 counter=0;
        for(uint256 i=1;i<= totalSupply ; i++) {
            if(   MarketGameAssets[i].owner   == _address ){
                counter++;
                //assets.push(MarketGameAssets[i]);
            }
        }
        return counter;
    }


    function getFullAssetIdAndTokenId() public view  returns(string[] memory,uint256[] memory,bool[] memory){
        string[] memory assetIds = new string[](totalSupply);
        uint256[] memory tokenIds = new uint256[](totalSupply);
        bool[] memory saleable = new bool[](totalSupply);
        for (uint256 i=0; i< totalSupply ; i++ ) {
            //mappingIndex start from Number 1 
            uint256 mappingIndex = i+1;
            assetIds[i]=MarketGameAssets[mappingIndex].assetId ;
            tokenIds[i]=MarketGameAssets[mappingIndex].tokenId ;
            saleable[i]=MarketGameAssets[mappingIndex].saleable ;
            
        }
        return (assetIds,tokenIds,saleable);
    }
    function getFullDataByType(uint256 _type) public view  returns(MainAssets[] memory){
        uint256 counter=0;
        uint256 totalSupplyType=getSupplyByType(_type);
        MainAssets[] memory assets = new MainAssets[](totalSupplyType);
        for (uint256 i=1 ; i<= totalSupply ; i++ ) {
            if(MarketGameAssets[i].asset_type == _type){
                assets[counter]  = MarketGameAssets[i] ;
                counter++;
            }
        }
        return assets;
    }

    function getFullDataByOwner(address _owner) public view returns(MainAssets[] memory){
        //fix bug
        //uint256 balanceOf = MetaverserNFT(nftContract).balanceOf(_owner);
        uint256 balanceOf =getSupplyByOwner(_owner);
        MainAssets[] memory assets = new MainAssets[](balanceOf);

        uint256 counter;
        counter=0;
        for(uint256 i=1;i<= totalSupply ; i++) {
            if(   MarketGameAssets[i].owner   == _owner  ){
                 assets[counter] = MarketGameAssets[i];
                counter++;
                //assets.push(MarketGameAssets[i]);
            }
        }

        return assets;
    }
 
    function getPrice(uint256 tokenId) public view returns(uint256){
        return MarketGameAssets[tokenId].price  ;
    }
    function getPayablePrice(uint256 tokenId) public view returns(uint256){
        bool contractOwnerIsOwner = (MarketGameAssets[tokenId].owner == owner() );
        uint256 price=0;
        if(contractOwnerIsOwner  ) {
            price= getPrice(tokenId);
        }else{
            price =  getPrice(tokenId) + ((getPrice(tokenId) * taxPercent)  /100 );
        }
        return price;
    }

}


