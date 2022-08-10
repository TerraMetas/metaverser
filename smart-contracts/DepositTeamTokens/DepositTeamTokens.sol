// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract DepositingTeamTokens is Ownable {
    ERC20 internal MTVToken ;
    address OwnerWallet;
    uint256 public tokenPoolLimit;
    uint256 public totalDepositAmount;
    uint256 public Part1Time;
    uint256 public Part1Percent;
    uint256 public Part2Time;
    uint256 public Part2Percent;
    uint256 public Part3Time;
    uint256 public Part3Percent;
    uint8 private numOfMonth ; 
    bool public Pause ;
    

    struct DepositStruct {
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
    mapping ( address => DepositStruct ) private  DepositUserdata;
    mapping (address => history[]) private userHistory;
    //mapping (uint256 => uint256) public totalStructs;

    constructor (address MTVTAddress) {

        Part1Time = 1667980800; //set exit time 
        Part2Time = 1671062400; //set exit time
        Part3Time = 1684886400; //set exit time
        Part1Percent = 0;
        Part2Percent = 3;
        Part3Percent = 100;
        numOfMonth = 12 ;
        MTVToken = ERC20(MTVTAddress) ;
        OwnerWallet = msg.sender;
        tokenPoolLimit = 1000000000000 ether ; // Deposit Limit Token  
        totalDepositAmount = 0; 
        Pause = false;
    }
    modifier onlyUser(address _sender) {
        require(DepositUserdata[_sender].time > 0, "User does not exist");
        _;
    }
    function depositToken(address _user,uint256 _amount)  public  onlyOwner   {
        require(!Pause,"Contract is Paused by owner");
        require(getPoolIsNotFull(0) ,"Deposit pool is full" );
        require(getPoolIsNotFull(_amount) ,"Deposit pool will be filled once your request is submitted" );
        uint256 totalAmount = DepositUserdata[_user].amount + _amount ;
        
        if(DepositUserdata[_user].amount == 0) {
           DepositUserdata[_user]=DepositStruct(block.timestamp , totalAmount,0,0);
        }else {
            DepositUserdata[_user].amount = totalAmount ;
        }
        

        totalDepositAmount = totalDepositAmount + _amount  ; // for fixing big decimal numbers add numOfMonth / 10 ** 18 token to user
        userHistory[_user].push(history(1,block.timestamp,totalAmount) );
        MTVToken.transferFrom(OwnerWallet , address(this),  _amount  );

        emit DepositingEvent(_user,_amount);

    }
    function claimToken(uint256 _amount) public onlyUser(msg.sender){
        require(!Pause,'Market is Paused by owner');
        uint256 totalToken = getReceivableToken(msg.sender);
        require(totalToken >= _amount   , "Not Enough Receivable Token At This Time" );
        userHistory[msg.sender].push(history(2,block.timestamp,_amount) );
        MTVToken.transfer(msg.sender,_amount);
        DepositUserdata[msg.sender].claim_amount = DepositUserdata[msg.sender].claim_amount + _amount;
    }

    //getter
    function getPoolIsNotFull(uint256 _amount) public view returns(bool){
        return totalDepositAmount + _amount <= tokenPoolLimit  ;
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
        totalToken = totalToken -  DepositUserdata[_player].claim_amount;
        return totalToken;
    }
    function getOneSliceOfPart3(address _player) public view returns(uint256){
        uint256 totalPart3Receivable = (getBalance(_player) * Part3Percent) / 100 ;
        uint256 oneSliceOfPart3 = totalPart3Receivable / numOfMonth ; 
        return oneSliceOfPart3;
    }
    function getPastMonthNumber() public view returns(uint256){
        if( block.timestamp >= Part3Time ) {
            uint256 periodTime = 2592000; //30 days in second
            uint256 diffTime =    block.timestamp - Part3Time   ;
            uint256 calcMonth = diffTime / periodTime ;  
            if(calcMonth > numOfMonth ) {
                calcMonth = numOfMonth;
            }
            return calcMonth;
        }else{
            return 0;
        }

    }
    function getBalance(address _player) public view onlyUser(_player) returns(uint256) {  
        return DepositUserdata[_player].amount;
    }
    function getClimed(address _player) public view onlyUser(_player) returns(uint256) {  
        return DepositUserdata[_player].claim_amount;
    }
    function getTimeStamp(address _player) public view  returns(uint256)  {
        return DepositUserdata[_player].time ;
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

    event DepositingEvent(address _sender,uint256 _amount);
    event ExitEvent(address _sender,uint256 _amount);  
    event WithdrawEvent(address _sender,uint256 _amount);  
    event ClaimEvent(address _sender,uint256 _amount);
    event PoolLimitChange(uint256 _amount);

}
