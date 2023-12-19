// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PolyImplementations} from "../src/registry/Implementations.sol";
import {ExclusiveImplementation} from "../src/accounts/ExclusiveImpl.sol";
import {ExclusiveRegistry} from "../src/registry/Exclusive.sol";

interface OneClickTradingInterface {
    function disableAuth(address _user) external payable returns (string memory _eventName, bytes memory _eventParam);

    function enableAuth(address _user, uint256 _expiry)
        external
        payable
        returns (string memory _eventName, bytes memory _eventParam);
}

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

        string[] memory _targets = new string[](3);
        bytes4[] memory _selectors = new bytes4[](3);

        _targets[0] = "Basic-v1";
        _selectors[0] = BasicInterface.withdraw.selector;

        _targets[1] = "One-Click-Trading-v1";
        _selectors[1] = OneClickTradingInterface.enableAuth.selector;

        _targets[2] = "One-Click-Trading-v1";
        _selectors[2] = OneClickTradingInterface.disableAuth.selector;

        registry.setTargetAndCallData(_targets, _selectors);

        ExclusiveImplementation exclusiveImpl = new ExclusiveImplementation(index, connectors, address(registry));

        PolyImplementations impls = PolyImplementations(0xda8AAcF7358f3E03820cD586df090E5da0387713);

        impls.removeImplementation(address(0xc01cAAf235A0a9f717274df5998f03D90d9ECCE3));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = ExclusiveImplementation.exclusiveCast.selector;
        selectors[1] = ExclusiveImplementation.enableAdditionalAuth.selector;
        selectors[2] = ExclusiveImplementation.disableAdditionalAuth.selector;

        impls.addImplementation(address(exclusiveImpl), selectors);

        vm.stopBroadcast();
    }
}
