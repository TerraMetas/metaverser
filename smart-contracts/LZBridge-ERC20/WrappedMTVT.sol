// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WrappedMTVT is OFT {
    constructor(
        string memory _name, // token name
        string memory _symbol, // token symbol
        address _layerZeroEndpoint, // local endpoint address
        address _owner // token owner used as a delegate in LayerZero Endpoint
    ) OFT(_name, _symbol, _layerZeroEndpoint, _owner) Ownable(_owner) {
        // your contract logic here
        _mint(msg.sender, 100 ether); // mints 100 tokens to the deployer
    }
}
