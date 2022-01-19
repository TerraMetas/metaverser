//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "./ERC20Token.sol";

contract sendMultiToken  {
    ERC20 internal MTVToken ;
    mapping(address=> uint256) ReceiverMap ;
    uint256 totalReceiver ;
    constructor(address tokenerc20){
        
        MTVToken = ERC20(tokenerc20) ;
        totalReceiver = 0;

    }
    function transferToken(address[] memory addr ,uint256 amount) public {
        for (uint8 i=0;i<addr.length ; i++) {
             MTVToken.transferFrom(msg.sender,addr[i],amount);
             ReceiverMap[address(addr[i])] = ReceiverMap[address(addr[i])]+amount;
        }
    }
    function getHistoryByAddress(address addr) public view returns(uint256) {
        return ReceiverMap[addr];
    }
    function getTokenAddress() public view returns(ERC20) {
        return MTVToken;
    }

}