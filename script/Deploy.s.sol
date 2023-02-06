// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PolyIndex} from "../src/registry/Index.sol";
import {PolyList} from "../src/registry/List.sol";
import {PolyConnectors} from "../src/registry/Connectors.sol";
import {PolyImplementations} from "../src/registry/Implementations.sol";
import {PolyAccount} from "../src/accounts/AccountProxy.sol";
import {DefaultImplementation} from "../src/accounts/DefaultImpl.sol";
import {MainImplementation} from "../src/accounts/MainImpl.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        PolyIndex index = new PolyIndex();
        PolyList list = new PolyList(address(index));
        PolyConnectors connectors = new PolyConnectors(address(index));
        PolyImplementations impls = new PolyImplementations(address(index));
        PolyAccount accountProxy = new PolyAccount(address(impls));
        DefaultImplementation defaultImpl = new DefaultImplementation(address(index));
        MainImplementation mainImpl = new MainImplementation(address(index), address(connectors));

        index.setBasics(deployerAddr, address(list), address(accountProxy));

        impls.setDefaultImplementation(address(defaultImpl));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MainImplementation.cast.selector;

        impls.addImplementation(address(mainImpl), selectors);

        vm.stopBroadcast();
    }
}
