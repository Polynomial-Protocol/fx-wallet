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
    
    event LogEnableAdditionalUser(
        address indexed user
    );
    
    event LogDisableAdditionalUser (
        address indexed user
    );
        

    /**
     * @dev Check for Auth if enabled.
     * @param user address/user/owner.
     */
    function isAuth(address user) public view returns (bool) {
        return _auth[user];
    }
    
    /**
     * @dev Check if Beta mode is enabled or not
     */
    function isBeta() public view returns (bool) {
        return _beta;
    }

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
     * @dev Enable New User.
     * @param user Owner address
     */
    function enable(address user) public {
        require(msg.sender == address(this) || msg.sender == polyIndex || isAuth(msg.sender), "not-self-index");
        require(user != address(0), "not-valid");
        require(!_additionalAuth[user], "already-enabled");
        _additionalAuth[user] = true;
        emit LogEnableAdditionalUser(user);
    }

    /**
     * @dev Disable User.
     * @param user Owner address
     */
    function disable(address user) public {
        require(msg.sender == address(this) || msg.sender == polyIndex || isAuth(msg.sender), "not-self");
        require(user != address(0), "not-valid");
        require(_auth[user], "already-disabled");
        delete _auth[user];
        emit LogDisableAdditionalUser(user);
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
     * @dev Delegate the calls to Connector.
     * @param _sig Signature that needs to be split into v, r, s
     */
    function splitSignature(bytes memory _sig) internal pure
    returns (uint8, bytes32, bytes32)
    {
        require(_sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(_sig, 32))
            // second 32 bytes
            s := mload(add(_sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_sig, 96)))
        }

        return (v, r, s);
    }
    
    /**
     * @dev Delegate the calls to Connector.
     * @param _message Message that was signed, to obtain address that signed it
     * @param _sig Signature after the message was signed
     */
    function recoverSigner(bytes32 _message, bytes memory _sig) pure public returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(_sig);

        return ecrecover(_message, v, r, s);
    }


    /**
     * @dev Delegate the calls to Connector.
     * @param _targetNamesAndCallData Abi encoded array of target names and calldata
     * @param _sig Signed Message of Trade Details
     * @param _origin Origin address
     */
    function exclusiveCast(bytes calldata _targetNamesAndCallData, bytes memory _sig, address _origin)
        external
        payable
        returns (
            bytes32 // Dummy return to fix polyIndex buildWithCast function
        )
    {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(_sig);
        
        bytes32 hashedTargetNamesAndCallData = keccak256(_targetNamesAndCallData);
    
        address signerOfMessage = ecrecover(hashedTargetNamesAndCallData, v, r, s);
        
        /*
            Step 1: check if signer of message is in additional auth or not - done
            Step 2: check if it's been 15 mins since the timestamp if so revert - done
            Step 3: check if certain targets and calldata are being used which shouldn't (need to make seperate module for this)
        */
        require(_additionalAuth[signerOfMessage], "not-authorized");
        require(isBeta(), "beta-not-enabled");
        
        
        (string[] memory _targetNames, bytes[] memory _datas, uint256 timestamp) = abi.decode(_targetNamesAndCallData, (string[], bytes[], uint256));
        require(timestamp + 15 minutes > block.timestamp, "timestamp-invalid");
        uint256 _length = _targetNames.length;
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