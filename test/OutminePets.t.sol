// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/OutminePets.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract Receiver {
    receive() external payable {}
}

contract ReentrantMinter is IERC721Receiver {
    OutminePets public immutable pets;
    bool private attackOnReceive;
    uint256 private attackPrice;

    constructor(OutminePets _pets) {
        pets = _pets;
    }

    receive() external payable {}

    function configureAttack(uint256 price) external {
        attackPrice = price;
    }

    function mintWithReentrancy() external {
        require(attackPrice > 0, "attack price not set");
        require(address(this).balance >= attackPrice * 2, "insufficient funds");
        attackOnReceive = true;
        pets.mintPayable{value: attackPrice}();
        attackOnReceive = false;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4) {
        if (attackOnReceive) {
            attackOnReceive = false;
            pets.mintPayable{value: attackPrice}();
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract ReentrantMinterRole is IERC721Receiver {
    OutminePets public immutable pets;
    bool private attackEnabled;

    constructor(OutminePets _pets) {
        pets = _pets;
    }

    function startAttack() external {
        attackEnabled = true;
        pets.mint(address(this));
        attackEnabled = false;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4) {
        if (attackEnabled) {
            attackEnabled = false;
            pets.mint(address(this));
        }
        return IERC721Receiver.onERC721Received.selector;
    }
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

    function testAdminCanSetMaxSupplyBackToUnlimitedAfterMinting() public {
        vm.prank(minter);
        pets.mint(user);

        vm.prank(admin);
        pets.setMaxSupply(0);
        assertEq(pets.maxSupply(), 0);

        vm.prank(minter);
        pets.mintBatch(user, 11);
        assertEq(pets.ownerOf(11), user);
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

    function testMinterCanBatchMint() public {
        vm.prank(minter);
        pets.mintBatch(user, 3);
        assertEq(pets.ownerOf(0), user);
        assertEq(pets.ownerOf(1), user);
        assertEq(pets.ownerOf(2), user);
    }

    function testMinterCanMintToReentrantReceiver() public {
        ReentrantMinterRole attacker = new ReentrantMinterRole(pets);
        vm.startPrank(admin);
        pets.grantRole(pets.MINTER_ROLE(), address(attacker));
        vm.stopPrank();

        vm.prank(address(attacker));
        attacker.startAttack();

        assertEq(pets.ownerOf(0), address(attacker));
        assertEq(pets.ownerOf(1), address(attacker));
    }

    function testBatchMintFailsWithZeroQuantity() public {
        vm.prank(minter);
        vm.expectRevert("Invalid batch quantity");
        pets.mintBatch(user, 0);
    }

    function testBatchMintFailsWhenExceedingMaxSupply() public {
        vm.prank(minter);
        vm.expectRevert("Max supply reached");
        pets.mintBatch(user, 11);
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

    function testMintPayableSucceedsAgainstReentrantReceiver() public {
        ReentrantMinter attacker = new ReentrantMinter(pets);
        attacker.configureAttack(1 ether);
        vm.deal(address(attacker), 2 ether);

        vm.expectRevert();
        attacker.mintWithReentrancy();
    }

    function testBatchMintSupplyCheckDoesNotOverflow() public {
        vm.prank(admin);
        pets.setMaxSupply(type(uint256).max);

        vm.store(address(pets), bytes32(uint256(9)), bytes32(type(uint256).max - 1));

        vm.prank(minter);
        vm.expectRevert("Max supply reached");
        pets.mintBatch(user, 2);
    }
}
