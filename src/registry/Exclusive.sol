// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IndexInterface {
    function master() external view returns (address);
}

contract Controllers {
    event LogExclusiveController(address indexed addr, bool indexed isChief);

    // PolyIndex Address.
    address public immutable polyIndex;

    constructor(address _polyIndex) {
        polyIndex = _polyIndex;
    }

    // Enabled Chief(Address of Chief => bool).
    mapping(address => bool) public chief;
    // Enabled Connectors(Connector name => address).
    mapping(string => address) public connectors;

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
        emit LogExclusiveController(_chiefAddress, chief[_chiefAddress]);
    }

}

contract ExclusiveRegistry is Controllers {
    // Restricted targets and function selector, bytes32 = keccak256(abi.encode(target, functionSelector))
    mapping(bytes32 => bool) internal _restrictedTargetsAndSelectors;
    
    constructor(address _polyIndex) Controllers(_polyIndex) {}
    
    event LogEnableAdditionalUser(
        address indexed user
    );
    
    event LogDisableAdditionalUser (
        address indexed user
    );

    /**
     * @dev Removing target and calldata that are restricted
     * @param _target Target in which the function exists
     * @param _functionSelector Function selector restricted from being called by exclusiveCast
     */
     function removeTargetAndCallData(string memory _target, bytes4 _functionSelector) external isChief returns (bool) {
            delete _restrictedTargetsAndSelectors[keccak256(abi.encode(_target, _functionSelector))];
            return true; 
     }
    
    /**
     * @dev Setting target and calldata that are restricted
     * @param _target Target in which the function exists
     * @param _functionSelector Function selector restricted from being called by exclusiveCast
     */
    function setTargetAndCallData(string[] memory _target, bytes4[] memory _functionSelector) external isChief returns (bool) {
        require(_target.length != 0, "length-invalid");
        require(_target.length == _functionSelector.length, "length-invalid");
        for(uint256 i = 0; i < _target.length; i++) {
            _restrictedTargetsAndSelectors[keccak256(abi.encode(_target[i], _functionSelector[i]))] = true;
        }
        return true;
    }
    
    function isValidTargetAndCallData(bytes32 _targetAndSelector) external view returns (bool) {
        return _restrictedTargetsAndSelectors[_targetAndSelector];
    }
}