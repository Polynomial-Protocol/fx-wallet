// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Variables} from "./Variables.sol";
import {Controllers} from "../registry/Connectors.sol";

interface ConnectorsInterface {
    function isConnectors(string[] calldata connectorNames) external view returns (bool, address[] memory);
}

contract Constants is Variables, Controllers {
    // polyIndex Address.
    address internal immutable polyIndex;
    // Connectors Address.
    address public immutable connectors;
    // Additional Auth Module(Address of Additional Auth => bool).
    mapping(address => bool) internal _additionalAuth;
    // Restricted targets and function selector
    mapping(string => mapping(bytes4 => bool)) internal _restrictedTargetsAndSelectors;

    constructor(address _polyIndex, address _connectors) Controllers(_polyIndex) {
        connectors = _connectors;
        polyIndex = _polyIndex;
    }
}

contract ExclusiveImplementation is Constants{
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
     * @dev Setting target and calldata that are restricted
     * @param _target Target in which the function exists
     * @param _functionSelector Function selector restricted from being called by exclusiveCast
     */
    function setTargetAndCallData(string memory _target, bytes4 _functionSelector) external isChief returns (bool) {
        _restrictedTargetsAndSelectors[_target][_functionSelector] = true;
        return true;
    }
    
    /**
     * @dev Removing target and calldata that are restricted
     * @param _target Target in which the function exists
     * @param _functionSelector Function selector restricted from being called by exclusiveCast
     */
     function removeTargetAndCallData(string memory _target, bytes4 _functionSelector) external isChief returns (bool) {
            delete _restrictedTargetsAndSelectors[_target][_functionSelector];
            return true; 
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
    function enable(address user) public isAuth(msg.sender){
        require(msg.sender == address(this) || msg.sender == polyIndex , "not-self-index");
        require(user != address(0), "not-valid");
        require(!_additionalAuth[user], "already-enabled");
        _additionalAuth[user] = true;
        emit LogEnableAdditionalUser(user);
    }

    /**
     * @dev Disable User.
     * @param user Owner address
     */
    function disable(address user) public isAuth(msg.sender){
        require(msg.sender == address(this) || msg.sender == polyIndex, "not-self");
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
    
    function getFunctionSelectorBytesMemory(
        bytes memory _bytes
    )
        internal
        pure
        returns (bytes4)
    {
        uint256 _start = 0;
        uint256 _length = 4;
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                tempBytes := mload(0x40)

                let lengthmod := and(_length, 32)

                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }
                mstore(tempBytes, _length)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            default {
                tempBytes := mload(0x40)
                mstore(tempBytes, 0)
                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return bytes4(tempBytes);
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
        
        require(_additionalAuth[signerOfMessage], "not-authorized");
        require(isBeta(), "beta-not-enabled");
        
        
        (string[] memory _targetNames, bytes[] memory _datas, uint256 timestamp) = abi.decode(_targetNamesAndCallData, (string[], bytes[], uint256));
        require(timestamp + 15 minutes > block.timestamp, "timestamp-invalid");
        
        uint256 _length = _targetNames.length;
        require(_length != 0, "1: length-invalid");
        require(_length == _datas.length, "1: array-length-invalid");

        for(uint256 i = 0; i < _length; i++) {
            bytes memory _calldata = _datas[i];
            bytes4 selector;
            require(!_restrictedTargetsAndSelectors[_targetNames[i]][getFunctionSelectorBytesMemory(_datas[i])], "restricted-target");
        }

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
    
    modifier isAuth(address user) {
        require(_auth[user], "not-wallet-owner");
        _;
    }
    
}