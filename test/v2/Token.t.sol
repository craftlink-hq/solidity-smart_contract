// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v2/Token.sol";

contract TokenTest is Test {
    Token token;
    address relayer = address(0x1);
    address user1 = address(0x2);

    function setUp() public {
        token = new Token(relayer);
    }

    function testClaim() public {
        vm.prank(user1);
        token.claim();
        assertEq(token.balanceOf(user1), 1000 * 10 ** 6);
    }

    function testCannotClaimTwice() public {
        vm.startPrank(user1);
        token.claim();
        vm.expectRevert("Already claimed");
        token.claim();
        vm.stopPrank();
    }

    function testClaimFor() public {
        vm.prank(relayer);
        token.claimFor(user1);
        assertEq(token.balanceOf(user1), 1000 * 10 ** 6);
    }
}
