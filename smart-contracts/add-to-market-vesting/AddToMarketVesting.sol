// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract AddToMarketVesting is Ownable {
    ERC20 internal MTVToken ;
    address OwnerWallet;
    uint256 public limitStack;
    uint256 public totalVestingAmount;
    uint256 public Part1Time;
    uint256 public Part1Percent;
    uint256 public Part2Time;
    uint256 public Part2Percent;
    uint256 public Part3Time;
    uint256 public Part3Percent;
    uint8 private numOfMonth ; 
    bool public Pause ;
    

    struct vestingData {
        uint256 time;
        uint256 amount;
        uint256 claim_time;
        uint256 claim_amount;
    }
    struct history {
        uint8 historyType;
        uint256 time;
        uint256 amount;


    }
    mapping ( address => vestingData ) private  vestingAddress;
    mapping (address => history[]) private userHistory;
    //mapping (uint256 => uint256) public totalStructs;

    constructor (address MTVTAddress) {

        Part1Time = 1666656000; //set exit time 
        Part2Time = 1671062400; //set exit time
        Part3Time = 1684886400; //set exit time
        Part1Percent = 1;
        Part2Percent = 3;
        Part3Percent = 96;
        numOfMonth = 24 ;
        MTVToken = ERC20(MTVTAddress) ;
        OwnerWallet = msg.sender;
        limitStack = 1000000000000 ether ; // Vesting Limit Token  
        totalVestingAmount = 0; 
        Pause = false;
    }
    modifier onlyUser(address _sender) {
        require(vestingAddress[_sender].time > 0, "User does not exist");
        _;
    }
    function addToVesting(address _user,uint256 _amount)  public  onlyOwner   {
        require(!Pause,"Vesting is Paused by owner");
        require(getVestingIsNotFull(0) ,"Vesting Pool is full" );
        require(getVestingIsNotFull(_amount) ,"Vesting will be filled once your request is submitted" );
        uint256 totalAmount = vestingAddress[_user].amount + _amount ;
        
        if(vestingAddress[_user].amount == 0) {
           vestingAddress[_user]=vestingData(block.timestamp , totalAmount,0,0);
        }else {
            vestingAddress[_user].amount = totalAmount ;
        }
        

        totalVestingAmount = totalVestingAmount + _amount  ; // for fixing big decimal numbers add numOfMonth / 10 ** 18 token to user
        userHistory[_user].push(history(1,block.timestamp,totalAmount) );
        MTVToken.transferFrom(OwnerWallet , address(this),  _amount  );

        emit VestingEvent(_user,_amount);

    }
    function claimToken(uint256 _amount) public onlyUser(msg.sender){
        require(!Pause,'Market is Paused by owner');
        uint256 totalToken = getReceivableToken(msg.sender);
        require(totalToken >= _amount   , "Not Enough Receivable Token At This Time" );
        userHistory[msg.sender].push(history(2,block.timestamp,_amount) );
        MTVToken.transfer(msg.sender,_amount);
        vestingAddress[msg.sender].claim_amount = vestingAddress[msg.sender].claim_amount + _amount;
    }

    //getter

    function getTokenVestingBalance() public view returns(uint256){
        return totalVestingAmount;
    }
    function getVestingIsNotFull(uint256 _amount) public view returns(bool){
        return totalVestingAmount + _amount <= limitStack  ;
    }
    function getReceivableToken(address _player) public view returns(uint256){
        uint256 totalToken=0;
        if(block.timestamp >= Part1Time   ) {
            totalToken = totalToken + ((getBalance(_player) * Part1Percent) / 100 );
        }
        if(block.timestamp >= Part2Time   ) {
            totalToken = totalToken + ((getBalance(_player) * Part2Percent) / 100 );
        }
        if(block.timestamp >= Part3Time   ) {
            uint256 oneSliceOfPart3 = getOneSliceOfPart3(_player)  ; 
            uint256 calcMonth =getPastMonthNumber() ; 
            if( calcMonth > 0) {

                totalToken =   (calcMonth * oneSliceOfPart3 ) + totalToken  ; //for fixing decimal numbers add token with formula 1 / 10 ** 18
            }
        }
        totalToken = totalToken -  vestingAddress[_player].claim_amount;
        return totalToken;
    }
    function getOneSliceOfPart3(address _player) public view returns(uint256){
        uint256 totalPart3Receivable = (getBalance(_player) * Part3Percent) / 100 ;
        uint256 oneSliceOfPart3 = totalPart3Receivable / numOfMonth ; 
        return oneSliceOfPart3;
    }
    function getPastMonthNumber() public view returns(uint256){
        if( block.timestamp >= Part3Time ) {
            uint256 periodTime = 120 ; //2592000; //30 days in second
            uint256 diffTime =    block.timestamp - Part3Time   ;
            uint256 calcMonth = diffTime / periodTime ;  
            if(calcMonth >= numOfMonth ) {
            calcMonth = numOfMonth;
            }
            return calcMonth;
        }else{
            return 0;
        }

    }
    function getBalance(address _player) public view onlyUser(_player) returns(uint256) {  
        return vestingAddress[_player].amount;
    }
    function getClimed(address _player) public view onlyUser(_player) returns(uint256) {  
        return vestingAddress[_player].claim_amount;
    }
    function getTimeStamp(address _player) public view  returns(uint256)  {
        return vestingAddress[_player].time ;
    }
    function getUserHistory(address _user) public view returns(history[] memory )  {
        history[] memory allUserHistory = new history[](userHistory[_user].length);

        for(uint256 i=0;i < userHistory[_user].length; i++) {
            allUserHistory[i]= userHistory[_user][i];
        }
        return allUserHistory;

    }
    //Setter
    function setPause(bool _pause) public onlyOwner{
         Pause = _pause;
    }
    function setOwnerWallet(address _newOwner) public onlyOwner{
        OwnerWallet = _newOwner ; 
    }

    event VestingEvent(address _sender,uint256 _amount);
    event ExitEvent(address _sender,uint256 _amount);  
    event WithdrawEvent(address _sender,uint256 _amount);  
    event ClaimEvent(address _sender,uint256 _amount);
    event VestingLimitChange(uint256 _amount);

}