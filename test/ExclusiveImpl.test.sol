// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {PolyIndex} from "../src/registry/Index.sol";
import {PolyList} from "../src/registry/List.sol";

import {PolyConnectors} from "../src/registry/Connectors.sol";
import {PolyImplementations} from "../src/registry/Implementations.sol";
import {PolyAccount} from "../src/accounts/AccountProxy.sol";
import {DefaultImplementation} from "../src/accounts/DefaultImpl.sol";
import {MainImplementation} from "../src/accounts/MainImpl.sol";
import {ExclusiveImplementation} from "../src/accounts/ExclusiveImpl.sol";
import {ExclusiveRegistry} from "../src/registry/Exclusive.sol";

import {SynthetixPerpConnector} from "./mocks/connectors/SynthetixPerp.sol";
import {BasicConnector} from "./mocks/connectors/Basic.sol";

interface BasicInterface {
    function withdraw(address, uint256, address, uint256, uint256) external;
    function deposit(address token, uint256 amt, uint256 getId, uint256 setId) external;
}

contract ExclusiveImplTest is Test {
    PolyIndex index;
    PolyList list;
    PolyConnectors connectors;
    PolyImplementations impls;
    PolyAccount accountProxy;
    DefaultImplementation defaultImpl;
    MainImplementation mainImpl;
    ExclusiveRegistry registry;
    ExclusiveImplementation exclusiveImpl;

    BasicConnector basic;
    SynthetixPerpConnector synthetixPerp;

    uint256 walletOwner = vm.envUint("PRIVATE_KEY");
    uint256 localKey = vm.envUint("PRIVATE_KEY_LOCAL");

    address public DSAwallet;
    uint256 public immutable localKeyExpiry = block.timestamp + 1000000;

    function setUp() public {
        index = new PolyIndex();
        list = new PolyList(address(index));
        connectors = new PolyConnectors(address(index));
        impls = new PolyImplementations(address(index));
        accountProxy = new PolyAccount(address(impls));
        defaultImpl = new DefaultImplementation(address(index));
        mainImpl = new MainImplementation(address(index), address(connectors));

        index.setBasics(address(this), address(list), address(accountProxy));

        impls.setDefaultImplementation(address(defaultImpl));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MainImplementation.cast.selector;

        impls.addImplementation(address(mainImpl), selectors);

        /*
        ** Add basic and synthetix perp connector
        */

        string[] memory names = new string[](2);
        address[] memory addrs = new address[](2);

        basic = new BasicConnector();
        synthetixPerp = new SynthetixPerpConnector();

        names[0] = basic.name();
        addrs[0] = address(basic);

        names[1] = synthetixPerp.name();
        addrs[1] = address(synthetixPerp);

        connectors.addConnectors(names, addrs);

        /*
        ** Deploying Exclusive Implementation
        */

        /* setting invalid target and selector */
        registry = new ExclusiveRegistry(address(index), address(connectors));
        exclusiveImpl = new ExclusiveImplementation(address(index), address(connectors), address(registry));

        string[] memory _targets = new string[](1);
        bytes4[] memory _selectors = new bytes4[](1);

        _targets[0] = "Basic-v1";
        _selectors[0] = BasicInterface.withdraw.selector;
        registry.setTargetAndCallData(_targets, _selectors);

        bytes4[] memory _selectorsCallable = new bytes4[](3);
        _selectorsCallable[0] = ExclusiveImplementation.exclusiveCast.selector;
        _selectorsCallable[1] = ExclusiveImplementation.enableAdditionalAuth.selector;
        _selectorsCallable[2] = ExclusiveImplementation.disableAdditionalAuth.selector;

        impls.addImplementation(address(exclusiveImpl), _selectorsCallable);

        /*
        ** Create SCW with wallet Owner
        ** set additional auth address to localkey with an expiry
        */

        DSAwallet = index.build(vm.addr(walletOwner), 1, address(0));

        vm.prank(vm.addr(walletOwner));
        ExclusiveImplementation(payable(DSAwallet)).enableAdditionalAuth(vm.addr(localKey), localKeyExpiry);
        vm.prank(DSAwallet);
        DefaultImplementation(payable(DSAwallet)).toggleBeta();
    }

    function test_LocalPrivateKeyCanPlaceTrades() public {
        string[] memory _targets = new string[](1);
        bytes[] memory _calldata = new bytes[](1);

        _targets[0] = "Basic-v1";
        _calldata[0] =
            abi.encodeWithSelector(BasicConnector.deposit.selector, address(123), uint256(123), uint256(0), uint256(0));

        bytes32 msgHash = keccak256(abi.encode(_targets, _calldata, block.timestamp));

        bytes32 msgSign = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(localKey, msgSign);

        bytes memory signature = abi.encodePacked(r, s, v);

        ExclusiveImplementation(payable(DSAwallet)).exclusiveCast(
            ExclusiveImplementation.CastInput(_targets, _calldata, block.timestamp), signature, address(0)
        );
    }

    function test_OtherPrivateKeysCantPlaceTrades() public {
        string[] memory _targets = new string[](1);
        bytes[] memory _calldata = new bytes[](1);

        _targets[0] = "Basic-v1";
        _calldata[0] =
            abi.encodeWithSelector(BasicConnector.deposit.selector, address(123), uint256(123), uint256(0), uint256(0));

        bytes32 msgHash = keccak256(abi.encode(_targets, _calldata, block.timestamp));

        bytes32 msgSign = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwner, msgSign);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("not-authorized");
        ExclusiveImplementation(payable(DSAwallet)).exclusiveCast(
            ExclusiveImplementation.CastInput(_targets, _calldata, block.timestamp), signature, address(0)
        );
    }

    function test_LocalPrivateKeyNotAllowedToWithdraw() public {
        string[] memory _targets = new string[](1);
        bytes[] memory _calldata = new bytes[](1);

        _targets[0] = "Basic-v1";
        _calldata[0] =
            abi.encodeWithSelector(BasicConnector.withdraw.selector, address(123), uint256(123), uint256(0), uint256(0));

        bytes32 msgHash = keccak256(abi.encode(_targets, _calldata, block.timestamp));

        bytes32 msgSign = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(localKey, msgSign);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("restricted-target");
        ExclusiveImplementation(payable(DSAwallet)).exclusiveCast(
            ExclusiveImplementation.CastInput(_targets, _calldata, block.timestamp), signature, address(0)
        );
    }

    function test_LocalKeyCallsFailAfterExpiry() public {
        string[] memory _targets = new string[](1);
        bytes[] memory _calldata = new bytes[](1);

        _targets[0] = "Basic-v1";
        _calldata[0] = abi.encodeWithSelector(
            BasicConnector.deposit.selector, address(123), uint256(123), uint256(0), uint256(100)
        );

        uint256 initialTimestamp = 1;

        bytes32 msgHash = keccak256(abi.encode(_targets, _calldata, initialTimestamp));

        bytes32 msgSign = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(localKey, msgSign);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.warp(localKeyExpiry + 1);
        vm.expectRevert("expired");
        ExclusiveImplementation(payable(DSAwallet)).exclusiveCast(
            ExclusiveImplementation.CastInput(_targets, _calldata, initialTimestamp), signature, address(0)
        );
    }

    function test_OrderPlacedWithExpiryBeyondCurrentBlockFails() public {
        string[] memory _targets = new string[](1);
        bytes[] memory _calldata = new bytes[](1);

        _targets[0] = "Basic-v1";
        _calldata[0] = abi.encodeWithSelector(
            BasicConnector.deposit.selector, address(123), uint256(123), uint256(0), uint256(100)
        );

        uint256 initialTimestamp = 100;

        bytes32 msgHash = keccak256(abi.encode(_targets, _calldata, initialTimestamp));

        bytes32 msgSign = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(localKey, msgSign);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("tx-expired");
        ExclusiveImplementation(payable(DSAwallet)).exclusiveCast(
            ExclusiveImplementation.CastInput(_targets, _calldata, initialTimestamp), signature, address(0)
        );
    }
}
