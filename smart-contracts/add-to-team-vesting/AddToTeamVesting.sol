// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract AddToTeamVesting is Ownable {
    ERC20 internal MTVToken ;
    address OwnerWallet;
    uint256 public limitStack;
    uint256 public totalVestingAmount;
    bool public Pause ;
    

    struct vestingData {
        uint256 time;
        uint256 amount;
        uint256 exit_time;
    }
    struct history {
        uint8 historyType;
        uint256 time;
        uint256 amount;


    }
    mapping ( address => vestingData[] ) private  vestingAddress;
    mapping (address => history[]) private userHistory;
    //mapping (address => uint256) public userClimed ;

    constructor (address MTVTAddress) {

        MTVToken = ERC20(MTVTAddress) ;
        OwnerWallet = msg.sender;
        limitStack = 10000000000000 ether ; // Vesting Limit Token  
        totalVestingAmount = 0; 
        Pause = false;
    }
    modifier onlyUser(address _sender) {
        require(vestingAddress[_sender].length > 0, "User does not exist");
        _;
    }
    //this function is just for test 
    function withdrawTokenByOwner(uint256 _amount) public onlyOwner{
          MTVToken.transfer(OwnerWallet,_amount);
    }
    function addToVesting(address _user,uint256 _amount,uint256 _time)  public  onlyOwner   {
        require(!Pause,"Vesting is Paused by owner");
        require(getVestingIsNotFull(0) ,"Vesting Pool is full" );
        require(getVestingIsNotFull(_amount) ,"Vesting will be filled once your request is submitted" );


        vestingAddress[_user].push(vestingData( block.timestamp,_amount,_time) );
        userHistory[_user].push(history(1,block.timestamp,_amount) );

        totalVestingAmount = totalVestingAmount + _amount  ; // for fixing big decimal numbers add numOfMonth / 10 ** 18 token to user
        MTVToken.transferFrom(OwnerWallet , address(this),  _amount  );

        emit VestingEvent(_user,_amount);

    }

    function claimToken(uint256 _amount) public onlyUser(msg.sender){
        require(!Pause,'Market is Paused by owner');
        uint256 totalToken = getReceivableToken(msg.sender);
        require(totalToken >= _amount   , "Not Enough Receivable Token At This Time" );
        userHistory[msg.sender].push(history(2,block.timestamp,_amount) );
        MTVToken.transfer(msg.sender,_amount);
    }

    //getter

    function getTokenVestingBalance() public view returns(uint256){
        return totalVestingAmount;
    }
    function getVestingIsNotFull(uint256 _amount) public view returns(bool){
        return totalVestingAmount + _amount <= limitStack  ;
    }
    function getReceivableToken(address _user) public view returns(uint256){
        uint256 totalToken=0;
        for(uint256 i=0;i < vestingAddress[_user].length; i++) {
            if(vestingAddress[_user][i].exit_time <= block.timestamp){
                totalToken += vestingAddress[_user][i].amount;
            }
            
        }
        totalToken = totalToken - getClimed(_user);
        return totalToken;
 
    }
 
    function getBalance(address _user) public view onlyUser(_user) returns(uint256) {  
        uint256 totalToken=0;
        for(uint256 i=0;i < vestingAddress[_user].length; i++) {
            totalToken += vestingAddress[_user][i].amount;
        }
        return totalToken;
    }
    function getClimed(address _user) public view onlyUser(_user) returns(uint256) {  
        uint256 totalToken=0;
        for(uint256 i=0;i < userHistory[_user].length; i++) {
            //historyType == 2 means claimed token
            if(userHistory[_user][i].historyType == 2) {
                    totalToken += userHistory[_user][i].amount;
            }
           
        }
        return totalToken;
    }
      function getAllData(address _user) public view returns(vestingData[] memory){
        vestingData[] memory allUserVesting = new vestingData[](vestingAddress[_user].length);
        for(uint256 i=0;i < vestingAddress[_user].length; i++) {

            allUserVesting[i]= vestingAddress[_user][i] ;
        }
        return allUserVesting;
 
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