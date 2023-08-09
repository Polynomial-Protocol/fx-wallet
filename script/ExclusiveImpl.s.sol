// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PolyImplementations} from "../src/registry/Implementations.sol";
import {ExclusiveImplementation} from "../src/accounts/ExclusiveImpl.sol";
import {ExclusiveRegistry} from "../src/registry/Exclusive.sol";

interface BasicInterface {
  function withdraw(address, uint256, address, uint256, uint256 ) external returns (string memory, bytes memory);
}

contract DeployDummy is Script {
    function run() external {
        console2.logBytes4(BasicInterface.withdraw.selector);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        console2.log(deployerAddr);

        address index = 0xC7a069dD24178DF00914d49Bf674A40A1420CF01;
        address connectors = 0x2BDC91973bfB5B16a5652520e3960Fd68D7be5C2;
        
        
        /* setting invalid target and selector */
        ExclusiveRegistry registry = new ExclusiveRegistry(index, connectors);

        string[] memory _targets = new string[](1);
        bytes4[] memory _selectors = new bytes4[](1);
        
        _targets[0] = 'Basic-v1';
        _selectors[0] = BasicInterface.withdraw.selector;

        registry.setTargetAndCallData(_targets, _selectors);

        ExclusiveImplementation exclusiveImpl= new ExclusiveImplementation(index, connectors, address(registry));

        PolyImplementations impls = PolyImplementations(0xaE548f68329876468263CD9cc4727b3f856f22d1);

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = ExclusiveImplementation.exclusiveCast.selector;
        selectors[1] = ExclusiveImplementation.enableAdditionalAuth.selector;
        selectors[2] = ExclusiveImplementation.disableAdditionalAuth.selector;

        impls.addImplementation(address(exclusiveImpl), selectors);

        vm.stopBroadcast();
    }
}