// SPDX-License-Identifier: MIT
//we dont use this
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SellTokenInvesting4 is Ownable {
    ERC20 internal MTVToken ;
    uint256 public rewardPercent; // 1/10 ^ 18 token every secends 
    uint256 public withdrawTimestamp ; 
    uint256 public totalMarketAmount;
    uint256 public totalMTVTAmount;
    uint256 public HardcapMarket; 
    uint256 public minimumBuyAmout ;
    uint256 public maximumBuyAmout ;

    uint256 public StartTime_A;
    uint256 public EndTime_A;
    uint256 public TokenPrice ;
    uint256 public BNBPrice;
    address public OwnerWallet;
    bool public Pause ;

    struct stakingData {
        uint256 buy_time;
        uint256 amount;
        uint256 bnb_amount;
        uint256 claim;
        uint256 withdraw_amount;
    }
    mapping ( address => stakingData ) private  stakingAddress;
    mapping (address => bool) private WhiteList;
 
    modifier onlyUser(address _sender) {
        require(stakingAddress[_sender].amount > 0  , "User does not exist");
        _;
    }


    //mapping (uint256 => uint256) public totalStructs;
    
    constructor (address MTVTAddress) {
        MTVToken = ERC20(MTVTAddress) ;
        rewardPercent = 8 ; // when for Annually 32% Then for 3 month we pay 10% 
        withdrawTimestamp = 7776000  ; //3 month in seconds
        OwnerWallet = msg.sender;
        minimumBuyAmout = 24 * (10 ** 16);
        maximumBuyAmout = 108 * (10 ** 16);
        BNBPrice = 416;
        TokenPrice =  (10 ** 16) / BNBPrice ;
        HardcapMarket = 240 * (10 ** 18) ;
        Pause = false;
    }

    function deposit() public payable {}
    function withdraw() public payable onlyOwner{
         payable(OwnerWallet).transfer( address(this).balance ) ;
    }
    function withdrawTokenByOwner(uint256 _amount) public onlyOwner{
          MTVToken.transfer(OwnerWallet,_amount);

    }
    
    function buyToken(uint256 BNBValue ) payable public{
        require (!Pause,'Market is Paused by owner');
        require (block.timestamp >= StartTime_A &&  block.timestamp <= EndTime_A,'Purchase time error!');
        require (WhiteList[msg.sender],'You are not in whitelist');

        require (HardcapMarket >= totalMarketAmount + BNBValue, 'Market Limit Error'  );
        require (TokenPrice > 0 , 'Price Cannot be zero by owner'); 
        require (BNBValue >=minimumBuyAmout  , 'Minimum purchase Error');
        uint256 amountToken = BNBValue / TokenPrice  * ( 10 ** 18 ) ;
        uint256 totalUserAmount = stakingAddress[msg.sender].amount + amountToken;
        uint256 BNBValueTotal = stakingAddress[msg.sender].bnb_amount + BNBValue;
        require (BNBValueTotal <= maximumBuyAmout , 'Maximum purchase Error');
        uint256 totalClaimed = stakingAddress[msg.sender].claim;
        uint256 totalTime = block.timestamp;
        if (stakingAddress[msg.sender].buy_time > 0 ) {
            totalTime = stakingAddress[msg.sender].buy_time;
        }
        stakingAddress[msg.sender]=stakingData( totalTime ,totalUserAmount , BNBValueTotal , totalClaimed , 0 );


        address stakSender = msg.sender;
        MTVToken.transferFrom(OwnerWallet, address(this), (amountToken *  108  ) / 100  );

        totalMarketAmount = totalMarketAmount + BNBValue ; 
        totalMTVTAmount = totalMTVTAmount + amountToken  ; 
        payable(OwnerWallet).transfer( BNBValue );
        emit PurchaseEvent(stakSender,amountToken,BNBValue,block.timestamp);
    }

    function claimReward() public onlyUser(msg.sender){
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0   , "Not Enough Reward Token" );
        MTVToken.transfer(msg.sender,reward);
        stakingAddress[msg.sender].claim = stakingAddress[msg.sender].claim + reward;

    }
    function withdrawToken(uint256 _amount) public onlyUser(msg.sender){
        
        require( block.timestamp >= (stakingAddress[msg.sender].buy_time + withdrawTimestamp)  , "Unable to withdraw at this time" );
        uint256 balanceOf = getBalance(msg.sender) - getWithdrawed(msg.sender)   ;
        require( balanceOf  >= _amount , "Not enough Tokens" );
        
        MTVToken.transfer(msg.sender,_amount);

        stakingAddress[msg.sender].withdraw_amount =  getWithdrawed(msg.sender)+  _amount;

        emit WithdrawEvent(msg.sender, _amount );
    }
    function exit() public onlyUser(msg.sender){
        require( block.timestamp >= (stakingAddress[msg.sender].buy_time + withdrawTimestamp)  , "Unable to withdraw at this time" );
        if(calculateReward(msg.sender) > 0) {
            claimReward();
        }
        uint256 balanceOf = getBalance(msg.sender) - getWithdrawed(msg.sender) ;
        MTVToken.transfer(msg.sender,balanceOf);
        stakingAddress[msg.sender]= stakingData(0,0,0,0,0) ;
        emit ExitEvent(msg.sender,balanceOf );

    }

    function calculateReward(address _player)  public view  onlyUser(_player) returns(uint256) {
        uint256 reward;
        uint256 nowTime = block.timestamp;
        uint256 userTime = stakingAddress[_player].buy_time;
        uint256 userAmount = stakingAddress[_player].amount;
        if( block.timestamp >= (stakingAddress[_player].buy_time + withdrawTimestamp )) { 
            reward = rewardPercent * userAmount  / 100 ;
        }else{
            reward = ( nowTime-userTime  ) * rewardPercent   * userAmount / (100 * withdrawTimestamp);
        }
        reward = reward -  stakingAddress[_player].claim;
        // reward =  (( nowTime - stakingAddress[_player].time )   *  rewardPercent   / withdrawTimestamp ) * takingAddress[_player].amount / withdrawTimestamp;
        return reward;

    }

    //Setter
    function addToWhiteList(address[] memory _whiteList,bool status) onlyOwner public {
        for(uint8 i;i < _whiteList.length;i++) {
            WhiteList[_whiteList[i]] = status ; 
        }
    }
    function setTokenPrice(uint256 _newPrice) onlyOwner public {
        TokenPrice = _newPrice;
    }  
    function setBNBPrice(uint256 _newPrice) onlyOwner public {
        BNBPrice = _newPrice;
        TokenPrice =  (10 ** 16) / BNBPrice ;  
    }  
    function setOwnerWallet(address _newWallet) onlyOwner public {
        OwnerWallet = _newWallet ;
    }
     function setMinimumAmount(uint256 _newAmount) onlyOwner public {
        minimumBuyAmout = _newAmount ;
    }
     function setMaximumAmount(uint256 _newAmount) onlyOwner public {
        maximumBuyAmout = _newAmount ;
    }
     function setHardcapMarket(uint256 _newAmount) onlyOwner public {
        HardcapMarket = _newAmount ;
    }
     function setStartTime_A(uint256 _newAmount) onlyOwner public {
        StartTime_A = _newAmount ;
    }
     function setEndTime_A(uint256 _newAmount) onlyOwner public {
        EndTime_A = _newAmount ;
    }
    function setPause(bool _newAmount) onlyOwner public {
        Pause = _newAmount ;
    }


    
    //getter
    function getExitTime(address _player) public view  onlyUser(_player) returns(uint256)  {
        uint pastTime =  block.timestamp - stakingAddress[_player].buy_time;
        if(withdrawTimestamp > pastTime ) {
            return withdrawTimestamp - pastTime;
        }else{
            return 0;
        }
    }

    function getBalance(address _player) public view onlyUser(_player) returns(uint256) {  
        return stakingAddress[_player].amount;
    }

    function getBNBBalance(address _player) public view onlyUser(_player) returns(uint256) {  
        return stakingAddress[_player].bnb_amount;
    }

    function getWithdrawed(address _player) public view onlyUser(_player) returns(uint256) {  
        return stakingAddress[_player].withdraw_amount;
    }

    function getClimed(address _player) public view returns(uint256) {
        return stakingAddress[_player].claim ;
    }

    function getTimeStamp(address _player) public view  returns(uint256)  {
        return stakingAddress[_player].buy_time ;
    }

    function getWhiteList(address _player) public view  returns(bool) {
        return WhiteList[_player] ; 
    }

    //event
    event PurchaseEvent(address _sender,uint256 _amount,uint256 _bnbAmount, uint256 time);
    event ExitEvent(address _sender,uint256 _amount);  
    event WithdrawEvent(address _sender,uint256 _amount);  
    event ClaimEvent(address _sender,uint256 _amount);
    event StakLimitChange(uint256 _amount);
}