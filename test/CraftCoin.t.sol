// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/v2/CraftCoin.sol";
import "../src/v2/Registry.sol";

contract CraftCoinTest is Test {
    Registry registry;
    CraftCoin craftCoin;
    address relayer = address(0x1);
    address artisan = address(0x2);

    function setUp() public {
        registry = new Registry(relayer);
        craftCoin = new CraftCoin(relayer, address(registry));

        // vm.prank(artisan);
        // registry.registerAsArtisan("ipfsHash");

        vm.prank(relayer);
        registry.registerAsArtisanFor(artisan, "ipfsHash");
    }

    function testMint() public {
        vm.prank(artisan);

        craftCoin.mint();
        assertEq(craftCoin.balanceOf(artisan), 50 * 10 ** 18);
    }

    function testCannotMintBeforeInterval() public {
        vm.prank(artisan);
        craftCoin.mint();

        vm.warp(block.timestamp + 29 days);
        vm.prank(artisan);
        vm.expectRevert("Cannot mint yet");

        craftCoin.mint();
    }
}
