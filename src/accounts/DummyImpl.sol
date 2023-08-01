// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Variables} from "./Variables.sol";

/**
 * @title FxWallet.
 * @dev fx Wallet.
 */

interface ConnectorsInterface {
    function isConnectors(string[] calldata connectorNames) external view returns (bool, address[] memory);
}

contract Constants is Variables {
    // polyIndex Address.
    address internal immutable polyIndex;
    // Connectors Address.
    address public immutable connectors;
    // Additional Auth Module(Address of Additional Auth => bool).
    mapping(address => bool) internal _additionalAuth;

    constructor(address _polyIndex, address _connectors) {
        connectors = _connectors;
        polyIndex = _polyIndex;
    }
}

contract DummyImplementation is Constants {
    constructor(address _polyIndex, address _connectors) Constants(_polyIndex, _connectors) {}

    event Dummy(uint256 data, address where);

    receive() external payable {}

    function aaaa(uint256 data, address where) external {
        require(_auth[msg.sender] || _additionalAuth[msg.sender]);

        emit Dummy(data, where);
    }

    function toggle(address _additional) external {
        bool current = _additionalAuth[_additional];

        _additionalAuth[_additional] = !current;
    }
}
