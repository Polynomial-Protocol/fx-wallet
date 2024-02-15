// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title PolyConnectors
 * @dev Registry for Connectors.
 */
interface IndexInterface {
    function master() external view returns (address);
}

interface ConnectorInterface {
    function name() external view returns (string memory);
}

contract Controllers {
    event LogController(address indexed addr, bool indexed isChief);

    // PolyIndex Address.
    address public immutable polyIndex;

    constructor(address _polyIndex) {
        polyIndex = _polyIndex;
    }

    // Enabled Chief(Address of Chief => bool).
    mapping(address => bool) public chief;
    // Enabled Connectors(Connector name => address).
    mapping(address => bool) public connectors;

    /**
     * @dev Throws if the sender not is Master Address from PolyIndex
     * or Enabled Chief.
     */
    modifier isChief() {
        require(chief[msg.sender] || msg.sender == IndexInterface(polyIndex).master(), "not-an-chief");
        _;
    }

    /**
     * @dev Toggle a Chief. Enable if disable & vice versa
     * @param _chiefAddress Chief Address.
     */
    function toggleChief(address _chiefAddress) external {
        require(msg.sender == IndexInterface(polyIndex).master(), "toggleChief: not-master");
        chief[_chiefAddress] = !chief[_chiefAddress];
        emit LogController(_chiefAddress, chief[_chiefAddress]);
    }
}

contract PolyLegacyConnectors is Controllers {
    event LogConnectorAdded(address indexed connector);
    event LogConnectorRemoved(address indexed connector);

    constructor(address _polyIndex) Controllers(_polyIndex) {}

    /**
     * @dev Add Connectors
     * @param _connectors Array of Connector Address.
     */
    function addConnectors(address[] calldata _connectors) external isChief {
        for (uint256 i = 0; i < _connectors.length; i++) {
            require(!connectors[_connectors[i]], "addConnectors: _connector added already");
            require(_connectors[i] != address(0), "addConnectors: _connectors address not vaild");
            ConnectorInterface(_connectors[i]).name(); // Checking if connector has function name()
            connectors[_connectors[i]] = true;
            emit LogConnectorAdded(_connectors[i]);
        }
    }

    /**
     * @dev Remove Connectors
     * @param _connectors Array of Connector Names.
     */
    function removeConnectors(address[] calldata _connectors) external isChief {
        for (uint256 i = 0; i < _connectors.length; i++) {
            require(connectors[_connectors[i]], "removeConnectors: _connectorName not added to update");
            emit LogConnectorRemoved(_connectors[i]);
            delete connectors[_connectors[i]];
        }
    }

    /**
     * @dev Check if Connector addresses are enabled.
     * @param _connectors Array of Connector Names.
     */
    function isConnectors(address[] calldata _connectors) external view returns (bool isOk) {
        isOk = true;
        for (uint256 i = 0; i < _connectors.length; i++) {
            if (!connectors[_connectors[i]]) {
                return false;
            }
        }
    }
}
