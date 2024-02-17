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

        address polyIndex = 0x2d4937ED79D434290c4baeA6d390b78c0bf907d8;
        PolyImplementations impls = PolyImplementations(0x331Cf6E3E59B18a8bc776A0F652aF9E2b42781c5);

        PolyLegacyConnectors legacyConnectors = new PolyLegacyConnectors(polyIndex);
        LegacyImplementation legacyImpl = new LegacyImplementation(polyIndex, address(legacyConnectors));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = LegacyImplementation.cast.selector;

        address[] memory connectorsToAdd = new address[](1);
        connectorsToAdd[0] = 0x3ba6A43ebf48520ea099ab07b411974f8494B390; // Base Synthetix Perp

        impls.addImplementation(address(legacyImpl), selectors);
        legacyConnectors.addConnectors(connectorsToAdd);

        vm.stopBroadcast();
    }
}
