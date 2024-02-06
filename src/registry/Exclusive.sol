// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IndexInterface {
    function master() external view returns (address);
}

interface ConnectorsInterface {
    function chief(address) external view returns (bool);
}

contract Controllers {
    // PolyIndex Address.
    address public immutable polyIndex;
    // Connectors Registry Address.
    address public immutable connectorsRegistry;

    constructor(address _polyIndex, address _connectorsRegistry) {
        polyIndex = _polyIndex;
        connectorsRegistry = _connectorsRegistry;
    }

    /**
     * @dev Throws if the sender not is Master Address from PolyIndex
     * or Enabled Chief.
     */
    modifier isChief() {
        ConnectorsInterface connectors = ConnectorsInterface(connectorsRegistry);
        require(connectors.chief(msg.sender) || msg.sender == IndexInterface(polyIndex).master(), "not-an-chief");
        _;
    }
}

contract ExclusiveRegistry is Controllers {
    // Restricted targets and function selector, bytes32 = keccak256(abi.encode(target, functionSelector))
    mapping(bytes32 => bool) internal _restrictedTargetsAndSelectors;

    constructor(address _polyIndex, address _connectorsRegistry) Controllers(_polyIndex, _connectorsRegistry) {}

    event LogRestrictedTargetAndSelectorAdded(string indexed target, bytes4 indexed functionSelector);

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
    function setTargetAndCallData(string[] memory _target, bytes4[] memory _functionSelector) external isChief {
        require(_target.length != 0, "length-invalid");
        require(_target.length == _functionSelector.length, "length-invalid");
        for (uint256 i = 0; i < _target.length; i++) {
            _restrictedTargetsAndSelectors[keccak256(abi.encode(_target[i], _functionSelector[i]))] = true;
            emit LogRestrictedTargetAndSelectorAdded(_target[i], _functionSelector[i]);
        }
    }

    function isRestrictedTargetAndCallData(bytes32 _targetAndSelector) external view returns (bool) {
        return _restrictedTargetsAndSelectors[_targetAndSelector];
    }
}
