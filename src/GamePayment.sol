// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract GamePayment is Ownable {
    event PaymentReceived(address indexed payer, uint256 amount, string itemId, string userId);
    event Withdrawal(address indexed to, uint256 amount);

    struct Payment {
        uint256 amount;
        string itemId;
        string userId;
    }

    // Store all payments per user
    mapping(address => Payment[]) public userPayments;

    constructor() Ownable(msg.sender) {}

    // Pay for a specific item
    function payForItem(string memory itemId, string memory userId) external payable {
        require(msg.value > 0, "No GLMR sent");
        userPayments[msg.sender].push(Payment(msg.value, itemId, userId));
        emit PaymentReceived(msg.sender, msg.value, itemId, userId);
    }

    // Owner can withdraw all GLMR
    function withdraw(address payable to) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No GLMR to withdraw");
        (bool sent,) = to.call{value: balance}("");
        require(sent, "Failed to send GLMR");
        emit Withdrawal(to, balance);
    }

    // Get contract balance
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
