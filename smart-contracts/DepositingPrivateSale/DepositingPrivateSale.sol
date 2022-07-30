// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract DepositingPrivateSale is Ownable {
    ERC20 internal MTVToken ;
    uint256 public tokenPoolLimit;
    uint256 public totalDepositAmount;
    uint256 private periodTime ; //30 days in second
    uint8 private numOfMonth ; 

    struct DepositStruct {
        uint256 time;
        uint256 amount;
        uint256 claim_time;
        uint256 claim_amount;
    }
    struct HistoryStruct {
        uint8 historyType;//1=depost, 2=claim 
        uint256 time;
        uint256 amount;


    }
     struct UserStruct {
        address owner;
        uint256 amount;
        uint256 time;
    }
    mapping ( address => DepositStruct ) private  DepositUserdata;
    mapping (address => HistoryStruct[]) private userHistory;
    address[] private WalletArray;

    constructor (address MTVTAddress) {

        periodTime =  2592000;
        numOfMonth = 12 ;
        MTVToken = ERC20(MTVTAddress) ;
        tokenPoolLimit = 1000000000000 ether ; // Deposit Limit Token  
        totalDepositAmount = 0; 
    }
    modifier onlyUser(address _sender) {
        require(DepositUserdata[_sender].time > 0, "User does not exist");
        _;
    }

    //operate
    function depositToken(uint256 _amount)  public {
        require(getPoolIsNotFull(0) ,"Deposit pool is full" );
        require(getPoolIsNotFull(_amount) ,"Deposit pool will be filled once your request is submitted" );
        uint256 totalAmount = DepositUserdata[msg.sender].amount + _amount ;
        if(DepositUserdata[msg.sender].amount == 0) {
           DepositUserdata[msg.sender]=DepositStruct(block.timestamp , totalAmount,0,0);
        }else {
            DepositUserdata[msg.sender].amount = totalAmount ;
        }
        
        totalDepositAmount = totalDepositAmount + _amount  ; // for fixing big decimal numbers add numOfMonth / 10 ** 18 token to user
        userHistory[msg.sender].push(HistoryStruct(1,block.timestamp,totalAmount) );
        WalletArray.push(msg.sender);
        MTVToken.transferFrom(msg.sender , address(this),  _amount  );

        emit DepositingEvent(msg.sender,_amount);
    }
    
    function claimToken(uint256 _amount) public onlyUser(msg.sender){
        uint256 totalToken = getReceivableToken(msg.sender);
        require(totalToken >= _amount   , "Not Enough Receivable Token At This Time" );
        userHistory[msg.sender].push(HistoryStruct(2,block.timestamp,_amount) );
        MTVToken.transfer(msg.sender,_amount);
        DepositUserdata[msg.sender].claim_amount = DepositUserdata[msg.sender].claim_amount + _amount;
    }

    //getter
    function getPoolIsNotFull(uint256 _amount) public view returns(bool) {
        return totalDepositAmount + _amount <= tokenPoolLimit  ;
    }
    
    function getReceivableToken(address _user) public view returns(uint256){
        uint256 totalToken=0;
        if(block.timestamp >= UnlockingTime(_user)   ) {
            uint256 oneSliceOfDepist = getOneSlice(_user)  ; 
            uint256 calcMonth =getPastMonthNumber(_user) ; 
            if( calcMonth > 0) {

                totalToken =   (calcMonth * oneSliceOfDepist ) + totalToken  ; //for fixing decimal numbers add token with formula 1 / 10 ** 18
            }
        }
        totalToken = totalToken -  DepositUserdata[_user].claim_amount;
        return totalToken;
    }
    function getOneSlice(address _user) public view returns(uint256){
        uint256 oneSliceOfDepist = getBalance(_user)  / numOfMonth ; 
        return oneSliceOfDepist;
    }
    function getPastMonthNumber(address _user) public view returns(uint256){
        if( block.timestamp >= UnlockingTime(_user) ) {
           
            uint256 diffTime =    block.timestamp - UnlockingTime(_user)   ;
            uint256 calcMonth = diffTime / periodTime ;  
            if(calcMonth > numOfMonth ) {
                calcMonth = numOfMonth;
            }
            return calcMonth;
        }else{
            return 0;
        }

    }
    function getBalance(address _user) public view returns(uint256) {  
        return DepositUserdata[_user].amount;
    }
    function getClimed(address _user) public view returns(uint256) {  
        return DepositUserdata[_user].claim_amount;
    }
    function getTimeStamp(address _user) public view  returns(uint256)  {
        return DepositUserdata[_user].time ;
    }
    function UnlockingTime(address _user) public view returns(uint256){
        return   getTimeStamp(_user) + ( periodTime * 3 ) ;
    }
    function getUserHistory(address _user) public view returns(HistoryStruct[] memory )  {
        HistoryStruct[] memory allUserHistory = new HistoryStruct[](userHistory[_user].length);

        for(uint256 i=0;i < userHistory[_user].length; i++) {
            allUserHistory[i]= userHistory[_user][i];
        }
        return allUserHistory;

    }
    function getAllUsers(uint16 _from,uint16 _to) public view returns (UserStruct[] memory) {
        require(_from<_to , '_from must be smaller than _to');
        if(_to > WalletArray.length) {
            _to = uint16(WalletArray.length);
        }
        UserStruct[] memory result = new UserStruct[](WalletArray.length);
        for (uint16 i = _from; i <_to ; i++) {
            address user = WalletArray[i];
            result[i] = UserStruct(user, getBalance(user), getTimeStamp(user));
        }
        return result;
    }
    function getTime() public view returns (uint256) {
        return block.timestamp;
    }


    event DepositingEvent(address _sender,uint256 _amount);
    event ExitEvent(address _sender,uint256 _amount);  
    event WithdrawEvent(address _sender,uint256 _amount);  
    event ClaimEvent(address _sender,uint256 _amount);
    event PoolLimitChange(uint256 _amount);

}
