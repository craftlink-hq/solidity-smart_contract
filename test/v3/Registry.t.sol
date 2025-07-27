// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v3/Registry.sol";

contract RegistryTest is Test {
    Registry registry;
    address relayer = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);

    function setUp() public {
        registry = new Registry(relayer);
    }

    function testRegisterAsArtisan() public {
        vm.prank(relayer);
        registry.registerAsArtisanFor(user1, "ipfsHash1");
        assertTrue(registry.isArtisan(user1));
        (string memory ipfsHash,,) = registry.getArtisanDetails(user1);
        assertEq(ipfsHash, "ipfsHash1");
    }

    function testCannotRegisterAsArtisanTwice() public {
        vm.startPrank(relayer);
        registry.registerAsArtisanFor(user1, "ipfsHash1");
        vm.expectRevert("User already registered as an artisan");
        registry.registerAsArtisanFor(user1, "ipfsHash2");
        vm.stopPrank();
    }

    function testRegisterAsClient() public {
        vm.prank(relayer);
        registry.registerAsClientFor(user1, "ipfsHash1");
        assertTrue(registry.isClient(user1));
        (string memory ipfsHash,) = registry.getClientDetails(user1);
        assertEq(ipfsHash, "ipfsHash1");
    }

    function testCannotRegisterAsClientTwice() public {
        vm.startPrank(relayer);
        registry.registerAsClientFor(user1, "ipfsHash1");
        vm.expectRevert("User already registered as a client");
        registry.registerAsClientFor(user1, "ipfsHash2");
        vm.stopPrank();
    }

    function testRegisterAsArtisanThenClient() public {
        vm.startPrank(relayer);
        registry.registerAsArtisanFor(user1, "ipfsHash1");
        registry.registerAsClientFor(user1, "ipfsHash2");
        vm.stopPrank();

        assertTrue(registry.isArtisan(user1));
        assertTrue(registry.isClient(user1));

        (string memory artisanIpfsHash,,) = registry.getArtisanDetails(user1);
        (string memory clientIpfsHash,) = registry.getClientDetails(user1);

        assertEq(artisanIpfsHash, "ipfsHash1");
        assertEq(clientIpfsHash, "ipfsHash2");
    }

    function testRegisterAsClientThenArtisan() public {
        vm.startPrank(relayer);
        registry.registerAsClientFor(user1, "ipfsHash1");
        registry.registerAsArtisanFor(user1, "ipfsHash2");
        vm.stopPrank();

        assertTrue(registry.isArtisan(user1));
        assertTrue(registry.isClient(user1));

        (string memory artisanIpfsHash,,) = registry.getArtisanDetails(user1);
        (string memory clientIpfsHash,) = registry.getClientDetails(user1);

        assertEq(artisanIpfsHash, "ipfsHash2");
        assertEq(clientIpfsHash, "ipfsHash1");
    }

    function testGetArtisanCount() public {
        vm.startPrank(relayer);
        registry.registerAsArtisanFor(user1, "ipfsHash1");
        registry.registerAsArtisanFor(user2, "ipfsHash2");
        vm.stopPrank();

        uint256 count = registry.getArtisanCount();
        assertEq(count, 2);
    }

    function testGetClientCount() public {
        vm.startPrank(relayer);
        registry.registerAsClientFor(user1, "ipfsHash1");
        registry.registerAsClientFor(user2, "ipfsHash2");
        vm.stopPrank();

        uint256 count = registry.getClientCount();
        assertEq(count, 2);
    }

    function testNonRelayerCannotRegisterFor() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not the relayer");
        registry.registerAsArtisanFor(user2, "ipfsHash2");
    }

    function testGetAllArtisanAddresses() public {
        vm.startPrank(relayer);
        registry.registerAsArtisanFor(user1, "ipfsHash1");
        registry.registerAsArtisanFor(user2, "ipfsHash2");
        vm.stopPrank();

        address[] memory artisanAddresses = registry.getAllArtisans();
        assertEq(artisanAddresses.length, 2);
        assertEq(artisanAddresses[0], user1);
        assertEq(artisanAddresses[1], user2);
    }

    function testGetAllClientAddresses() public {
        vm.startPrank(relayer);
        registry.registerAsClientFor(user1, "ipfsHash1");
        registry.registerAsClientFor(user2, "ipfsHash2");
        vm.stopPrank();

        address[] memory clientAddresses = registry.getAllClients();
        assertEq(clientAddresses.length, 2);
        assertEq(clientAddresses[0], user1);
        assertEq(clientAddresses[1], user2);
    }
}
