// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/OutmineItems.sol";

contract OutmineItemsTest is Test {
    OutmineItems items;
    address admin = address(0xA);
    address minter = address(0xB);
    address pauser = address(0xC);
    address user = address(0xD);

    function setUp() public {
        vm.startPrank(admin);
        items = new OutmineItems();
        items.grantMinterRole(minter);
        items.grantRole(items.PAUSER_ROLE(), pauser);
        vm.stopPrank();
    }

    function testAdminCanSetURI() public {
        vm.prank(admin);
        items.setURI("https://example.com/metadata/");
        assertEq(
            items.uri(1),
            string(abi.encodePacked("https://example.com/metadata/", "1"))
        );
    }

    function testMinterCanMint() public {
        vm.prank(minter);
        items.mint(user, 1, 5, "");
        assertEq(items.balanceOf(user, 1), 5);
    }

    function testMinterCanMintBatch() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 3;
        amounts[1] = 4;
        vm.prank(minter);
        items.mintBatch(user, ids, amounts, "");
        assertEq(items.balanceOf(user, 1), 3);
        assertEq(items.balanceOf(user, 2), 4);
    }

    function testMinterCanMintBatchAddr() public {
        address[] memory accounts = new address[](2);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        accounts[0] = user;
        accounts[1] = admin;
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 2;
        amounts[1] = 3;
        vm.prank(minter);
        items.mintBatchAddr(accounts, ids, amounts, "");
        assertEq(items.balanceOf(user, 1), 2);
        assertEq(items.balanceOf(admin, 2), 3);
    }

    function testPauserCanPauseAndUnpause() public {
        vm.prank(pauser);
        items.pause();
        vm.expectRevert();
        vm.prank(minter);
        items.mint(user, 1, 1, "");
        vm.prank(pauser);
        items.unpause();
        vm.prank(minter);
        items.mint(user, 1, 1, "");
        assertEq(items.balanceOf(user, 1), 1);
    }

    function testSoulboundBlocksTransfer() public {
        vm.prank(admin);
        items.setSoulbound(1, true);
        vm.prank(minter);
        items.mint(user, 1, 1, "");
        vm.prank(user);
        vm.expectRevert("Soulbound: non-transferable");
        items.safeTransferFrom(user, admin, 1, 1, "");
    }

    function testSoulboundAllowsMintAndBurn() public {
        vm.prank(admin);
        items.setSoulbound(1, true);
        vm.prank(minter);
        items.mint(user, 1, 1, "");
        vm.prank(user);
        items.burn(user, 1, 1);
        assertEq(items.balanceOf(user, 1), 0);
    }

    function testNonSoulboundAllowsTransfer() public {
        vm.prank(minter);
        items.mint(user, 2, 1, "");
        vm.prank(user);
        items.safeTransferFrom(user, admin, 2, 1, "");
        assertEq(items.balanceOf(admin, 2), 1);
    }

    function testAdminCanSetAndUnsetSoulbound() public {
        vm.prank(admin);
        items.setSoulbound(3, true);
        assertTrue(items.isSoulbound(3));
        vm.prank(admin);
        items.setSoulbound(3, false);
        assertFalse(items.isSoulbound(3));
    }
}
