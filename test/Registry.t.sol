// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/v2/Registry.sol";

contract RegistryTest is Test {
    Registry registry;
    address relayer = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);

    function setUp() public {
        registry = new Registry(relayer);
    }

    function testRegisterAsArtisan() public {
        vm.prank(user1);
        registry.registerAsArtisan("ipfsHash1");
        assertEq(uint256(registry.userTypes(user1)), uint256(Registry.UserType.Artisan));
        (string memory ipfsHash,,) = registry.getArtisanDetails(user1);
        assertEq(ipfsHash, "ipfsHash1");
    }

    function testCannotRegisterAsArtisanTwice() public {
        vm.startPrank(user1);
        registry.registerAsArtisan("ipfsHash1");
        vm.expectRevert("User already registered as an artisan");
        registry.registerAsArtisan("ipfsHash2");
        vm.stopPrank();
    }

    function testRegisterAsClient() public {
        vm.prank(user1);
        registry.registerAsClient("ipfsHash1");
        assertEq(uint256(registry.userTypes(user1)), uint256(Registry.UserType.Client));
        (string memory ipfsHash,) = registry.getClientDetails(user1);
        assertEq(ipfsHash, "ipfsHash1");
    }

    function testCannotRegisterAsClientTwice() public {
        vm.startPrank(user1);
        registry.registerAsClient("ipfsHash1");
        vm.expectRevert("User already registered as a client");
        registry.registerAsClient("ipfsHash2");
        vm.stopPrank();
    }

    function testRelayerRegisterForArtisan() public {
        vm.prank(relayer);
        registry.registerAsArtisanFor(user2, "ipfsHash2");
        assertEq(uint256(registry.userTypes(user2)), uint256(Registry.UserType.Artisan));
    }

    function testRelayerCannotRegisterForClient() public {
        vm.prank(relayer);
        registry.registerAsClientFor(user2, "ipfsHash2");
        assertEq(uint256(registry.userTypes(user2)), uint256(Registry.UserType.Client));
    }

    function testNonRelayerCannotRegisterFor() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not the relayer");
        registry.registerAsArtisanFor(user2, "ipfsHash2");
    }
}
