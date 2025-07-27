// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v2/Registry.sol";

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
        assertTrue(registry.isArtisan(user1));
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
        assertTrue(registry.isClient(user1));
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
        assertTrue(registry.isArtisan(user2));
    }

    function testRelayerRegisterForClient() public {
        vm.prank(relayer);
        registry.registerAsClientFor(user2, "ipfsHash2");
        assertTrue(registry.isClient(user2));
    }

    function testRegisterAsArtisanThenClient() public {
        vm.startPrank(user1);
        registry.registerAsArtisan("ipfsHash1");
        registry.registerAsClient("ipfsHash2");
        vm.stopPrank();

        assertTrue(registry.isArtisan(user1));
        assertTrue(registry.isClient(user1));

        (string memory artisanIpfsHash,,) = registry.getArtisanDetails(user1);
        (string memory clientIpfsHash,) = registry.getClientDetails(user1);

        assertEq(artisanIpfsHash, "ipfsHash1");
        assertEq(clientIpfsHash, "ipfsHash2");
    }

    function testRegisterAsClientThenArtisan() public {
        vm.startPrank(user1);
        registry.registerAsClient("ipfsHash1");
        registry.registerAsArtisan("ipfsHash2");
        vm.stopPrank();

        assertTrue(registry.isArtisan(user1));
        assertTrue(registry.isClient(user1));

        (string memory artisanIpfsHash,,) = registry.getArtisanDetails(user1);
        (string memory clientIpfsHash,) = registry.getClientDetails(user1);

        assertEq(artisanIpfsHash, "ipfsHash2");
        assertEq(clientIpfsHash, "ipfsHash1");
    }

    function testRelayerRegisterArtisanThenClient() public {
        vm.prank(relayer);
        registry.registerAsArtisanFor(user1, "ipfsHash1");
        vm.prank(relayer);
        registry.registerAsClientFor(user1, "ipfsHash2");

        assertTrue(registry.isArtisan(user1));
        assertTrue(registry.isClient(user1));

        (string memory artisanIpfsHash,,) = registry.getArtisanDetails(user1);
        (string memory clientIpfsHash,) = registry.getClientDetails(user1);

        assertEq(artisanIpfsHash, "ipfsHash1");
        assertEq(clientIpfsHash, "ipfsHash2");
    }

    function testRelayerRegisterClientThenArtisan() public {
        vm.prank(relayer);
        registry.registerAsClientFor(user1, "ipfsHash1");
        vm.prank(relayer);
        registry.registerAsArtisanFor(user1, "ipfsHash2");

        assertTrue(registry.isArtisan(user1));
        assertTrue(registry.isClient(user1));

        (string memory artisanIpfsHash,,) = registry.getArtisanDetails(user1);
        (string memory clientIpfsHash,) = registry.getClientDetails(user1);

        assertEq(artisanIpfsHash, "ipfsHash2");
        assertEq(clientIpfsHash, "ipfsHash1");
    }

    function testGetArtisanCount() public {
        vm.prank(user1);
        registry.registerAsArtisan("ipfsHash1");
        vm.prank(user2);
        registry.registerAsArtisan("ipfsHash2");

        uint256 count = registry.getArtisanCount();
        assertEq(count, 2);
    }

    function testClientCount() public {
        vm.prank(user1);
        registry.registerAsClient("ipfsHash1");
        vm.prank(user2);
        registry.registerAsClient("ipfsHash2");

        uint256 count = registry.getClientCount();
        assertEq(count, 2);
    }

    function testNonRelayerCannotRegisterFor() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not the relayer");
        registry.registerAsArtisanFor(user2, "ipfsHash2");
    }
}
