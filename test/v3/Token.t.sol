// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v3/Token.sol";

contract TokenTest is Test {
    Token token;
    address relayer = address(0x1);
    address user1 = address(0x2);

    function setUp() public {
        token = new Token(relayer);
    }

    function testMint() public {
        uint256 initialSupply = 1000 * 10 ** 6;
        token.mint(user1, initialSupply);
        assertEq(token.balanceOf(user1), initialSupply);
    }

    function testBurn() public {
        uint256 initialSupply = 1000 * 10 ** 6;
        token.mint(user1, initialSupply);
        uint256 burnAmount = 300 * 10 ** 6;

        vm.prank(user1);
        token.burn(burnAmount);

        assertEq(token.balanceOf(user1), initialSupply - burnAmount);
    }

    function testCannotClaimTwice() public {
        vm.startPrank(relayer);
        token.claimFor(user1);
        vm.expectRevert("Already claimed");
        token.claimFor(user1);
        vm.stopPrank();
    }

    function testClaim() public {
        vm.prank(relayer);
        token.claimFor(user1);
        assertEq(token.balanceOf(user1), 1000 * 10 ** 6);
    }
}
