// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v3/CraftCoin.sol";
import "../../src/v3/Registry.sol";

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
        vm.prank(relayer);
        craftCoin.mintFor(artisan);

        assertEq(craftCoin.balanceOf(artisan), 50 * 10 ** 18);
    }

    function testBurn() public {
        vm.prank(relayer);
        craftCoin.mintFor(artisan);

        uint256 initialBalance = craftCoin.balanceOf(artisan);
        uint256 burnAmount = 20 * 10 ** 18;

        craftCoin.burnFor(artisan, burnAmount);

        assertEq(craftCoin.balanceOf(artisan), initialBalance - burnAmount);
    }

    function testCannotMintIfNotArtisan() public {
        address nonArtisan = address(0x3);
        vm.prank(relayer);
        vm.expectRevert("Not an artisan");

        craftCoin.mintFor(nonArtisan);
    }

    function testCannotMintForIfNotRelayer() public {
        address nonRelayer = address(0x3);
        vm.prank(nonRelayer);
        vm.expectRevert("Caller is not the relayer");

        craftCoin.mintFor(artisan);
    }

    function testCannotMintBeforeInterval() public {
        vm.prank(relayer);
        craftCoin.mintFor(artisan);

        vm.warp(block.timestamp + 29 days);
        vm.prank(relayer);
        vm.expectRevert("Cannot mint yet");

        craftCoin.mintFor(artisan);
    }
}
