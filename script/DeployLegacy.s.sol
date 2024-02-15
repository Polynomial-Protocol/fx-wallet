// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {LegacyImplementation} from "../src/accounts/LegacyImpl.sol";
import {PolyLegacyConnectors} from "../src/registry/LegacyConnectors.sol";
import {PolyImplementations} from "../src/registry/Implementations.sol";

contract DeployLegacy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address polyIndex = 0xF18C8a7C78b60D4b7EE00cBc1D5B62B643d03404;
        PolyImplementations impls = PolyImplementations(0x6c4c4971936F091Ba351a4e9B621FcCDC03455e4);

        PolyLegacyConnectors legacyConnectors = new PolyLegacyConnectors(polyIndex);
        LegacyImplementation legacyImpl = new LegacyImplementation(polyIndex, address(legacyConnectors));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = LegacyImplementation.cast.selector;

        address[] memory connectorsToAdd = new address[](1);
        connectorsToAdd[0] = 0x9A1c9A85214314eAb70ed34e0C8D3796b9A91955; // Base Sepolia Synthetix Perp

        impls.addImplementation(address(legacyImpl), selectors);
        legacyConnectors.addConnectors(connectorsToAdd);

        vm.stopBroadcast();
    }
}
