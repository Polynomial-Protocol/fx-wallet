// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Variables} from "./Variables.sol";

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

contract ExclusiveImplementation is Constants {
    constructor(address _polyIndex, address _connectors) Constants(_polyIndex, _connectors) {}
    
    event Exclusive(uint256 data, address where);
    
    receive() external payable {}
    
    event LogExclusiveCast(
        address indexed origin,
        address indexed sender,
        uint256 value,
        string[] targetsNames,
        address[] targets,
        string[] eventNames,
        bytes[] eventParams
    );


    function decodeEvent(bytes memory response)
        internal
        pure
        returns (string memory _eventCode, bytes memory _eventParams)
    {
        if (response.length > 0) {
            (_eventCode, _eventParams) = abi.decode(response, (string, bytes));
        }
    }
    
    /**
     * @dev Check if Beta mode is enabled or not
     */
    function isBeta() public view returns (bool) {
        return _beta;
    }

    /**
     * @dev Delegate the calls to Connector.
     * @param _target Connector address
     * @param _data CallData of function.
     */
    function spell(address _target, bytes memory _data) internal returns (bytes memory response) {
        require(_target != address(0), "target-invalid");
        assembly {
            let succeeded := delegatecall(gas(), _target, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize()

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                returndatacopy(0x00, 0x00, size)
                revert(0x00, size)
            }
        }
    }

    /**
     * @dev This is the main function, Where all the different functions are called
     * from Smart Account.
     * @param _targetNames Array of Connector address.
     * @param _datas Array of Calldata.
     */
    function exclusiveCast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin)
        external
        payable
        returns (
            bytes32 // Dummy return to fix polyIndex buildWithCast function
        )
    {
        
        uint256 _length = _targetNames.length;
        require(_auth[msg.sender] || msg.sender == polyIndex || _additionalAuth[msg.sender], "not-authorized");
        require(_length != 0, "1: length-invalid");
        require(_length == _datas.length, "1: array-length-invalid");
        
        
        string[] memory eventNames = new string[](_length);
        bytes[] memory eventParams = new bytes[](_length);

        (bool isOk, address[] memory _targets) = ConnectorsInterface(connectors).isConnectors(_targetNames);

        require(isOk, "1: not-connector");

        for (uint256 i = 0; i < _length; i++) {
            bytes memory response = spell(_targets[i], _datas[i]);
            (eventNames[i], eventParams[i]) = decodeEvent(response);
        }

        emit LogExclusiveCast(_origin, msg.sender, msg.value, _targetNames, _targets, eventNames, eventParams);

    }
    
}