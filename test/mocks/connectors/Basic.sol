// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract BasicConnector {
    string public constant name = "Basic-v1";
    
    
    function deposit(address token, uint256 amt, uint256 getId, uint256 setId)         
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam){
    }
    function withdraw(address token, uint256 amt, address payable to, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {}
}