// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PolyImplementations} from "../src/registry/Implementations.sol";
import {DummyImplementation} from "../src/accounts/DummyImpl.sol";

contract DeployDummy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        console2.log(deployerAddr);

        address index = 0xC7a069dD24178DF00914d49Bf674A40A1420CF01;
        address connectors = 0x2BDC91973bfB5B16a5652520e3960Fd68D7be5C2;

        DummyImplementation dummyImpl = new DummyImplementation(index, connectors);

        PolyImplementations impls = PolyImplementations(0xaE548f68329876468263CD9cc4727b3f856f22d1);

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = DummyImplementation.aaaa.selector;
        selectors[1] = DummyImplementation.toggle.selector;

        impls.addImplementation(address(dummyImpl), selectors);

        vm.stopBroadcast();
    }
}
