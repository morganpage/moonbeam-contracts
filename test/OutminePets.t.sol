// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/OutminePets.sol";

contract Receiver {
    receive() external payable {}
}

contract OutminePetsTest is Test {
    OutminePets pets;
    address admin = address(0xA);
    address minter = address(0xB);
    address pauser = address(0xC);
    address user = address(0xD);

    function setUp() public {
        vm.startPrank(admin);
        pets = new OutminePets();
        pets.setMaxSupply(10);
        pets.setMintPrice(1 ether);
        pets.setBaseURI("https://api.example.com/");
        pets.grantRole(pets.MINTER_ROLE(), minter);
        pets.grantRole(pets.PAUSER_ROLE(), pauser);
        vm.stopPrank();
    }

    function testAdminCanSetMaxSupply() public {
        vm.prank(admin);
        pets.setMaxSupply(20);
        assertEq(pets.maxSupply(), 20);
    }

    function testAdminCanSetMintPrice() public {
        vm.prank(admin);
        pets.setMintPrice(2 ether);
        assertEq(pets.mintPrice(), 2 ether);
    }

    function testAdminCanSetBaseURI() public {
        vm.prank(admin);
        pets.setBaseURI("https://new.example.com/");
        // No getter, but no revert means success
    }

    function testMinterCanMint() public {
        vm.prank(minter);
        pets.mint(user);
        assertEq(pets.ownerOf(0), user);
    }

    function testMintPayableWorks() public {
        vm.deal(user, 2 ether);
        vm.prank(user);
        pets.mintPayable{value: 1 ether}();
        assertEq(pets.ownerOf(0), user);
    }

    function testMintPayableFailsIfNotEnoughValue() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert("Incorrect Ether value sent");
        pets.mintPayable{value: 0.5 ether}();
    }

    function testMintPayableFailsIfPriceNotSet() public {
        vm.prank(admin);
        pets.setMintPrice(0);
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert("Mint price not set");
        pets.mintPayable{value: 1 ether}();
    }

    function testMintFailsWhenPaused() public {
        vm.prank(pauser);
        pets.pause();
        vm.prank(minter);
        vm.expectRevert();
        pets.mint(user);
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert();
        pets.mintPayable{value: 1 ether}();
    }

    function testWithdraw() public {
        Receiver receiver = new Receiver();
        vm.deal(user, 1 ether);
        vm.prank(user);
        pets.mintPayable{value: 1 ether}();
        vm.prank(admin);
        pets.withdraw(payable(address(receiver)));
        assertEq(address(pets).balance, 0);
        assertEq(address(receiver).balance, 1 ether);
    }

    function testNonAdminCannotSetMaxSupply() public {
        vm.expectRevert();
        pets.setMaxSupply(100);
    }

    function testNonMinterCannotMint() public {
        vm.expectRevert();
        pets.mint(user);
    }

    function testNonPauserCannotPause() public {
        vm.expectRevert();
        pets.pause();
    }
}
