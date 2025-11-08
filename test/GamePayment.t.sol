// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/GamePayment.sol";

contract Receiver {
    receive() external payable {}
}

contract GamePaymentTest is Test {
    GamePayment payment;
    address owner = address(0xA);
    address user1 = address(0xB);
    address user2 = address(0xC);

    function setUp() public {
        payment = new GamePayment();
        payment.transferOwnership(owner);
    }

    function testPayForItemRecordsPaymentAndEmitsEvent() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        // userId = "user-1001", itemId = "item-42"
        payment.payForItem{value: 1 ether}("item-42", "user-1001");
        (uint256 amount, string memory itemId, string memory userId) = payment.userPayments(user1, 0);
        assertEq(amount, 1 ether);
        assertEq(keccak256(bytes(itemId)), keccak256(bytes("item-42")));
        assertEq(keccak256(bytes(userId)), keccak256(bytes("user-1001")));
    }

    function testMultiplePaymentsFromSameUser() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        payment.payForItem{value: 1 ether}("item-1", "user-2001");
        vm.prank(user1);
        payment.payForItem{value: 2 ether}("item-2", "user-2002");
        (uint256 amount1, string memory itemId1, string memory userId1) = payment.userPayments(user1, 0);
        (uint256 amount2, string memory itemId2, string memory userId2) = payment.userPayments(user1, 1);
        assertEq(amount1, 1 ether);
        assertEq(keccak256(bytes(itemId1)), keccak256(bytes("item-1")));
        assertEq(keccak256(bytes(userId1)), keccak256(bytes("user-2001")));
        assertEq(amount2, 2 ether);
        assertEq(keccak256(bytes(itemId2)), keccak256(bytes("item-2")));
        assertEq(keccak256(bytes(userId2)), keccak256(bytes("user-2002")));
    }

    function testWithdrawOnlyOwner() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        payment.payForItem{value: 1 ether}("item-123", "user-3001");
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        vm.prank(user1);
        payment.withdraw(payable(user1));
    }

    function testWithdrawSendsFundsAndEmitsEvent() public {
        vm.deal(user1, 2 ether);
        Receiver receiver = new Receiver();
        vm.prank(user1);
        payment.payForItem{value: 2 ether}("item-7", "user-4001");
        uint256 balBefore = address(receiver).balance;
        vm.prank(owner);
        payment.withdraw(payable(address(receiver)));
        assertEq(address(receiver).balance, balBefore + 2 ether);
        assertEq(address(payment).balance, 0);
    }

    function testPayForItemRevertsIfNoValue() public {
        vm.expectRevert("No GLMR sent");
        payment.payForItem("item-1", "user-5001");
    }

    function testContractBalance() public {
        vm.deal(user2, 3 ether);
        vm.prank(user2);
        payment.payForItem{value: 3 ether}("item-99", "user-6001");
        assertEq(payment.contractBalance(), 3 ether);
    }
}
