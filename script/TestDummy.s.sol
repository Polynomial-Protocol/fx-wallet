// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {DummyImplementation} from "../src/accounts/DummyImpl.sol";

contract TestDummy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address scw = address(0x0);

        DummyImplementation dummy = DummyImplementation(scw);

        dummy.aaaa(1.45e18, address(42069));

        vm.stopBroadcast();
    }
}
