// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract StakingToken is Ownable {
    ERC20 internal MTVToken ;
    uint256 public rewardPercent; // 1/10 ^ 18 token every secends 
    uint256 public withdrawTimestamp ; 
    uint256 public limitStack;
    uint256 public totalStakAmount;
    bool public Pause ;

    struct stakingData {
        uint256  time;
        uint256  amount;
        uint256 claim;
        uint256 withdraw_amount;
    }
    mapping  ( address => stakingData ) private  stakingAddress;

    //mapping (uint256 => uint256) public totalStructs;
    
    constructor () {
        MTVToken = ERC20(0xB92c5e0135A510A4a3A8803F143d2Cb085BBAf73) ;
        rewardPercent = 10 ; // when for Annually 30% Then for 4 month we pay 10% 
        withdrawTimestamp =  10368000  ; //4 month in seconds
        limitStack = 10000000 ether ; // Staking Limit Token  
        totalStakAmount = 0; 
        Pause = false;
    }
    modifier onlyUser(address _sender) {

        require(stakingAddress[_sender].time > 0, "User does not exist");
        _;
    }

    

    function staking(uint256 _amount)  public   returns(bool)  {

        require(!Pause,"Stak is Paused by owner");
        require(stakingAddress[msg.sender].time == 0 , "User exists but cannot stak again");
        require(getStakIsNotFull(0) ,"Stake Pool is full" );
        require(getStakIsNotFull(_amount) ,"Stak will be filled once your request is submitted" );

        stakingAddress[msg.sender]=stakingData(block.timestamp,_amount,0,0);
        address stakSender = msg.sender;
        totalStakAmount = totalStakAmount+ _amount;
        MTVToken.transferFrom(stakSender,address(this),  _amount);
        emit StakingEvent(stakSender,_amount);
        return true;

    }
    
    function claimReward() public onlyUser(msg.sender){
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0   , "Not Enough Reward Token" );
        MTVToken.transfer(msg.sender,reward);
        stakingAddress[msg.sender].claim = stakingAddress[msg.sender].claim + reward;

    }
    function withdraw(uint256 _amount) public onlyUser(msg.sender){
        
        require( block.timestamp >= (stakingAddress[msg.sender].time + withdrawTimestamp)  , "Unable to withdraw at this time" );
        uint256 balanceOf = getBalance(msg.sender) - getWithdrawed(msg.sender)   ;
        require( balanceOf  >= _amount , "Not enough Tokens" );
        
        MTVToken.transfer(msg.sender,_amount);

        stakingAddress[msg.sender].withdraw_amount =  getWithdrawed(msg.sender)+  _amount;

        emit WithdrawEvent(msg.sender, _amount );
    }
    function exit() public onlyUser(msg.sender){
        require( block.timestamp >= (stakingAddress[msg.sender].time + withdrawTimestamp)  , "Unable to withdraw at this time" );
        if(calculateReward(msg.sender) > 0) {
            claimReward();
        }
        uint256 balanceOf = getBalance(msg.sender) - getWithdrawed(msg.sender) ;
        MTVToken.transfer(msg.sender,balanceOf);
        stakingAddress[msg.sender]= stakingData(0,0,0,0) ;
        emit ExitEvent(msg.sender,balanceOf );

    }

    function calculateReward(address _player)  public view  onlyUser(_player) returns(uint256) {

        require(stakingAddress[_player].time != 0    , "User Not Exist");
        
        uint256 reward;
        uint256 nowTime = block.timestamp;
        uint256 userTime = stakingAddress[_player].time;
        uint256 userAmount = stakingAddress[_player].amount;
        if( block.timestamp >= (stakingAddress[_player].time + withdrawTimestamp )) { 
            reward = rewardPercent * userAmount  / 100 ;
        }else{
            reward = ( nowTime-userTime  ) * rewardPercent   * userAmount / (100 * withdrawTimestamp);
        }
        reward = reward -  stakingAddress[_player].claim;
        // reward =  (( nowTime - stakingAddress[_player].time )   *  rewardPercent   / withdrawTimestamp ) * takingAddress[_player].amount / withdrawTimestamp;
        return reward;

    }

    function getTokenStakingBalance() public view returns(uint256){
        return totalStakAmount;
    }
    function getStakIsNotFull(uint256 _amount) public view returns(bool){
        return totalStakAmount + _amount <= limitStack  ;
    }
    function getBalance(address _player) public view onlyUser(_player) returns(uint256) {  
        return stakingAddress[_player].amount;
    }
    function getWithdrawed(address _player) public view onlyUser(_player) returns(uint256) {  
        return stakingAddress[_player].withdraw_amount;
    }
    function getExitTime(address _player) public view  onlyUser(_player) returns(uint256)  {
        uint pastTime =  block.timestamp - stakingAddress[_player].time;
        if(withdrawTimestamp > pastTime ) {
            return withdrawTimestamp - pastTime;
        }else{
            return 0;
        }
    }
    function getClimed(address _player) public view returns(uint256) {
        return stakingAddress[_player].claim ;
    }
    function getTimeStamp(address _player) public view  returns(uint256)  {
        return stakingAddress[_player].time ;
    }
    function setStakingLimit(uint256 _amount) public onlyOwner{
        limitStack = _amount;
        emit StakLimitChange(_amount);
    }
    function setPause(bool _pause) public onlyOwner{
         Pause = _pause;
    }

    event StakingEvent(address _sender,uint256 _amount);
    event ExitEvent(address _sender,uint256 _amount);  
    event WithdrawEvent(address _sender,uint256 _amount);  
    event ClaimEvent(address _sender,uint256 _amount);
    event StakLimitChange(uint256 _amount);

}