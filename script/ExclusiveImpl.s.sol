// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PolyImplementations} from "../src/registry/Implementations.sol";
import {ExclusiveImplementation} from "../src/accounts/ExclusiveImpl.sol";
import {ExclusiveRegistry} from "../src/registry/Exclusive.sol";

interface BasicInterface {
    function withdraw(address, uint256, address, uint256, uint256) external returns (string memory, bytes memory);
}

contract DeployDummy is Script {
    function run() external {
        console2.logBytes4(BasicInterface.withdraw.selector);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        console2.log(deployerAddr);

        address index = 0xe7FcA4a9cCC5DE4917C98277e7BeE81782a5Cd01;
        address connectors = 0x95325058C51Acc796E35F3D0309Ff098c4f818F1;

        /* setting invalid target and selector */
        ExclusiveRegistry registry = new ExclusiveRegistry(index, connectors);

        string[] memory _targets = new string[](1);
        bytes4[] memory _selectors = new bytes4[](1);

        _targets[0] = "Basic-v1";
        _selectors[0] = BasicInterface.withdraw.selector;

        registry.setTargetAndCallData(_targets, _selectors);

        ExclusiveImplementation exclusiveImpl = new ExclusiveImplementation(index, connectors, address(registry));

        PolyImplementations impls = PolyImplementations(0xda8AAcF7358f3E03820cD586df090E5da0387713);
        
        impls.removeImplementation(address(0x4cDE9e380549BB3CFb70C1393332c48Ce9BfCff0));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = ExclusiveImplementation.exclusiveCast.selector;
        selectors[1] = ExclusiveImplementation.enableAdditionalAuth.selector;
        selectors[2] = ExclusiveImplementation.disableAdditionalAuth.selector;

        impls.addImplementation(address(exclusiveImpl), selectors);

        vm.stopBroadcast();
    }
}
