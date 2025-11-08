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
        pets = new OutminePets(10, 1 ether);
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
        vm.expectRevert(abi.encodeWithSelector(IncorrectPayment.selector, 0.5 ether, 1 ether));
        pets.mintPayable{value: 0.5 ether}();
    }

    function testMintPayableFailsIfPriceNotSet() public {
        vm.prank(admin);
        pets.setMintPrice(0);
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(MintPriceNotSet.selector);
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

    // ==================== Batch Minting Tests ====================

    function testBatchMintCreatesMultipleTokens() public {
        vm.prank(minter);
        pets.mintBatch(user, 3);
        assertEq(pets.ownerOf(0), user);
        assertEq(pets.ownerOf(1), user);
        assertEq(pets.ownerOf(2), user);
        assertEq(pets.totalSupply(), 3);
    }

    function testBatchMintEmitsEvent() public {
        vm.prank(minter);
        vm.expectEmit(true, false, false, true);
        emit BatchMint(user, 0, 5);
        pets.mintBatch(user, 5);
    }

    function testBatchMintFailsWithZeroQuantity() public {
        vm.prank(minter);
        vm.expectRevert(InvalidBatchQuantity.selector);
        pets.mintBatch(user, 0);
    }

    function testBatchMintFailsWhenExceedingMaxSupply() public {
        vm.prank(minter);
        vm.expectRevert(MaxSupplyReached.selector);
        pets.mintBatch(user, 11); // Max supply is 10
    }

    function testBatchMintFailsWhenPaused() public {
        vm.prank(pauser);
        pets.pause();
        vm.prank(minter);
        vm.expectRevert();
        pets.mintBatch(user, 3);
    }

    function testBatchMintRespectsTotalSupply() public {
        vm.startPrank(minter);
        pets.mintBatch(user, 5);
        assertEq(pets.totalSupply(), 5);
        pets.mintBatch(user, 3);
        assertEq(pets.totalSupply(), 8);
        vm.stopPrank();
    }

    // ==================== Batch URI Tests ====================

    function testSetBatchBaseURI() public {
        vm.prank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch1/");

        vm.prank(minter);
        pets.mint(user);

        string memory uri = pets.tokenURI(0);
        assertEq(uri, "ipfs://batch1/0");
    }

    function testMultipleBatchBaseURIs() public {
        vm.startPrank(admin);
        pets.setBatchBaseURI(0, 2, "ipfs://gen1/");
        pets.setBatchBaseURI(3, 5, "ipfs://gen2/");
        vm.stopPrank();

        vm.startPrank(minter);
        for (uint256 i = 0; i < 6; i++) {
            pets.mint(user);
        }
        vm.stopPrank();

        assertEq(pets.tokenURI(0), "ipfs://gen1/0");
        assertEq(pets.tokenURI(1), "ipfs://gen1/1");
        assertEq(pets.tokenURI(2), "ipfs://gen1/2");
        assertEq(pets.tokenURI(3), "ipfs://gen2/3");
        assertEq(pets.tokenURI(4), "ipfs://gen2/4");
        assertEq(pets.tokenURI(5), "ipfs://gen2/5");
    }

    function testBatchURIFallsBackToGlobalURI() public {
        vm.prank(admin);
        pets.setBatchBaseURI(0, 2, "ipfs://batch/");

        vm.prank(minter);
        pets.mintBatch(user, 5);

        // Tokens 0-2 use batch URI
        assertEq(pets.tokenURI(0), "ipfs://batch/0");
        assertEq(pets.tokenURI(2), "ipfs://batch/2");

        // Tokens 3-4 use global URI
        assertEq(pets.tokenURI(3), "https://api.example.com/3");
        assertEq(pets.tokenURI(4), "https://api.example.com/4");
    }

    function testUpdateBatchBaseURI() public {
        vm.startPrank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://original/");
        pets.updateBatchBaseURI(0, "ipfs://updated/");
        vm.stopPrank();

        vm.prank(minter);
        pets.mint(user);

        assertEq(pets.tokenURI(0), "ipfs://updated/0");
    }

    function testUpdateBatchRangeExpandAndShrink() public {
        vm.prank(admin);
        pets.setBatchBaseURI(2, 4, "ipfs://batch/");

        // Expand range to cover more tokens
        vm.prank(admin);
        pets.updateBatchRange(0, 1, 5);

        vm.prank(minter);
        pets.mintBatch(user, 6);

        assertEq(pets.tokenURI(1), "ipfs://batch/1");
        assertEq(pets.tokenURI(5), "ipfs://batch/5");

        // Shrink range; removed tokens should fall back to global URI
        vm.prank(admin);
        pets.updateBatchRange(0, 3, 4);

        assertEq(pets.tokenURI(1), "https://api.example.com/1");
        assertEq(pets.tokenURI(3), "ipfs://batch/3");
        assertEq(pets.tokenURI(4), "ipfs://batch/4");
        assertEq(pets.tokenURI(5), "https://api.example.com/5");
    }

    function testUpdateBatchRangeFailsWhenBatchFrozen() public {
        vm.startPrank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch/");
        pets.freezeBatchBaseURI(0);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(BatchURIFrozen.selector);
        pets.updateBatchRange(0, 1, 5);
    }

    function testUpdateBatchRangeCannotOverlapFrozenBatch() public {
        vm.startPrank(admin);
        pets.setBatchBaseURI(0, 2, "ipfs://frozen/");
        pets.freezeBatchBaseURI(0);
        pets.setBatchBaseURI(3, 5, "ipfs://active/");
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(BatchURIFrozen.selector);
        pets.updateBatchRange(1, 2, 4); // token 2 belongs to frozen batch 0
    }

    function testSetBatchBaseURIFailsWithInvalidRange() public {
        vm.prank(admin);
        vm.expectRevert(InvalidBatchRange.selector);
        pets.setBatchBaseURI(5, 5, "ipfs://invalid/");
    }

    function testSetBatchBaseURIFailsWithStartGreaterThanEnd() public {
        vm.prank(admin);
        vm.expectRevert(InvalidBatchRange.selector);
        pets.setBatchBaseURI(5, 2, "ipfs://invalid/");
    }

    function testGetBatchInfo() public {
        vm.prank(admin);
        pets.setBatchBaseURI(0, 9, "ipfs://collection/");

        vm.prank(minter);
        pets.mint(user);

        BatchInfo memory info = pets.getBatchInfo(0);
        assertEq(info.startTokenId, 0);
        assertEq(info.endTokenId, 9);
        assertEq(info.baseURI, "ipfs://collection/");
        assertEq(info.frozen, false);
    }

    function testGetBatchCount() public {
        assertEq(pets.getBatchCount(), 0);

        vm.startPrank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch1/");
        assertEq(pets.getBatchCount(), 1);

        pets.setBatchBaseURI(5, 9, "ipfs://batch2/");
        assertEq(pets.getBatchCount(), 2);
        vm.stopPrank();
    }

    function testGetBatchByIndex() public {
        vm.startPrank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch1/");
        pets.setBatchBaseURI(5, 9, "ipfs://batch2/");
        vm.stopPrank();

        BatchInfo memory batch0 = pets.getBatchByIndex(0);
        assertEq(batch0.baseURI, "ipfs://batch1/");

        BatchInfo memory batch1 = pets.getBatchByIndex(1);
        assertEq(batch1.baseURI, "ipfs://batch2/");
    }

    function testGetBatchByIndexFailsWithInvalidIndex() public {
        vm.expectRevert(InvalidBatchRange.selector);
        pets.getBatchByIndex(0);
    }

    function testNonAdminCannotSetBatchBaseURI() public {
        vm.prank(user);
        vm.expectRevert();
        pets.setBatchBaseURI(0, 4, "ipfs://unauthorized/");
    }

    function testNonAdminCannotUpdateBatchBaseURI() public {
        vm.prank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://original/");

        vm.prank(user);
        vm.expectRevert();
        pets.updateBatchBaseURI(0, "ipfs://unauthorized/");
    }

    // ==================== URI Freezing Tests ====================

    function testFreezeBaseURI() public {
        vm.startPrank(admin);
        pets.freezeBaseURI();
        assertTrue(pets.isBaseURIFrozen());

        vm.expectRevert(URIFrozen.selector);
        pets.setBaseURI("https://new.example.com/");
        vm.stopPrank();
    }

    function testFreezeBatchBaseURI() public {
        vm.startPrank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch/");
        pets.freezeBatchBaseURI(0);

        BatchInfo memory info = pets.getBatchInfo(0);
        assertTrue(info.frozen);

        vm.expectRevert(BatchURIFrozen.selector);
        pets.updateBatchBaseURI(0, "ipfs://new/");
        vm.stopPrank();
    }

    function testFreezeBatchBaseURIFailsWithInvalidIndex() public {
        vm.prank(admin);
        vm.expectRevert(InvalidBatchRange.selector);
        pets.freezeBatchBaseURI(0);
    }

    function testNonAdminCannotFreezeBaseURI() public {
        vm.prank(user);
        vm.expectRevert();
        pets.freezeBaseURI();
    }

    function testNonAdminCannotFreezeBatchBaseURI() public {
        vm.prank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch/");

        vm.prank(user);
        vm.expectRevert();
        pets.freezeBatchBaseURI(0);
    }

    // ==================== MintPayableTo Tests ====================

    function testMintPayableToWorks() public {
        vm.deal(user, 2 ether);
        vm.prank(user);
        address recipient = address(0xE);
        pets.mintPayableTo{value: 1 ether}(recipient);
        assertEq(pets.ownerOf(0), recipient);
    }

    function testMintPayableToEmitsEvent() public {
        vm.deal(user, 2 ether);
        vm.prank(user);
        address recipient = address(0xE);

        vm.expectEmit(true, true, true, true);
        emit PaidMint(user, recipient, 0, 1 ether);
        pets.mintPayableTo{value: 1 ether}(recipient);
    }

    function testMintPayableToFailsWithIncorrectPayment() public {
        vm.deal(user, 2 ether);
        vm.prank(user);
        address recipient = address(0xE);

        vm.expectRevert(abi.encodeWithSelector(IncorrectPayment.selector, 0.5 ether, 1 ether));
        pets.mintPayableTo{value: 0.5 ether}(recipient);
    }

    function testMintPayableToFailsWhenPaused() public {
        vm.prank(pauser);
        pets.pause();

        vm.deal(user, 2 ether);
        vm.prank(user);
        vm.expectRevert();
        pets.mintPayableTo{value: 1 ether}(address(0xE));
    }

    // ==================== Total Supply Tests ====================

    function testTotalSupplyStartsAtZero() public {
        assertEq(pets.totalSupply(), 0);
    }

    function testTotalSupplyIncrementsOnMint() public {
        vm.startPrank(minter);
        pets.mint(user);
        assertEq(pets.totalSupply(), 1);
        pets.mint(user);
        assertEq(pets.totalSupply(), 2);
        vm.stopPrank();
    }

    function testTotalSupplyWithBatchMint() public {
        vm.prank(minter);
        pets.mintBatch(user, 5);
        assertEq(pets.totalSupply(), 5);
    }

    // ==================== Max Supply Tests ====================

    function testSetMaxSupplyBelowCurrentSupplyFails() public {
        vm.prank(minter);
        pets.mintBatch(user, 5);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(MaxSupplyTooLow.selector, 3, 5));
        pets.setMaxSupply(3);
    }

    function testMintFailsWhenMaxSupplyReached() public {
        vm.startPrank(minter);
        pets.mintBatch(user, 10); // Max supply is 10

        vm.expectRevert(MaxSupplyReached.selector);
        pets.mint(user);
        vm.stopPrank();
    }

    function testMintPayableFailsWhenMaxSupplyReached() public {
        vm.prank(minter);
        pets.mintBatch(user, 10);

        vm.deal(user, 2 ether);
        vm.prank(user);
        vm.expectRevert(MaxSupplyReached.selector);
        pets.mintPayable{value: 1 ether}();
    }

    function testSetMaxSupplyToZeroAllowsUnlimited() public {
        vm.prank(admin);
        pets.setMaxSupply(0);
        assertEq(pets.maxSupply(), 0);

        // Should be able to mint more than 10 now
        vm.prank(minter);
        pets.mintBatch(user, 15);
        assertEq(pets.totalSupply(), 15);
    }

    function testSetMaxSupplyToZeroAfterMintingAllowsUnlimited() public {
        // Mint some tokens while cap is 10
        vm.prank(minter);
        pets.mintBatch(user, 5);
        assertEq(pets.totalSupply(), 5);

        // Switching to unlimited should still be allowed
        vm.prank(admin);
        pets.setMaxSupply(0);
        assertEq(pets.maxSupply(), 0);

        // Now we can mint past the original cap
        vm.prank(minter);
        pets.mintBatch(user, 10);
        assertEq(pets.totalSupply(), 15);
    }

    // ==================== Withdraw Tests ====================

    function testWithdrawFailsWithNoFunds() public {
        vm.prank(admin);
        vm.expectRevert(NoFundsToWithdraw.selector);
        pets.withdraw(payable(user));
    }

    function testWithdrawEmitsEvent() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        pets.mintPayable{value: 1 ether}();

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user, 1 ether);
        pets.withdraw(payable(user));
    }

    function testNonAdminCannotWithdraw() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        pets.mintPayable{value: 1 ether}();

        vm.prank(user);
        vm.expectRevert();
        pets.withdraw(payable(user));
    }

    // ==================== Receive Function Tests ====================

    function testReceiveFunctionAcceptsEther() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        (bool success,) = address(pets).call{value: 0.5 ether}("");
        assertTrue(success);
        assertEq(address(pets).balance, 0.5 ether);
    }

    function testReceiveFunctionEmitsEvent() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit EtherReceived(user, 0.5 ether);
        (bool success,) = address(pets).call{value: 0.5 ether}("");
        assertTrue(success);
    }

    // ==================== Pause/Unpause Tests ====================

    function testUnpauseWorks() public {
        vm.startPrank(pauser);
        pets.pause();
        pets.unpause();
        vm.stopPrank();

        vm.prank(minter);
        pets.mint(user); // Should succeed
        assertEq(pets.ownerOf(0), user);
    }

    function testNonPauserCannotUnpause() public {
        vm.prank(pauser);
        pets.pause();

        vm.prank(user);
        vm.expectRevert();
        pets.unpause();
    }

    // ==================== Token URI Tests ====================

    function testTokenURIFailsForNonexistentToken() public {
        vm.expectRevert();
        pets.tokenURI(0);
    }

    function testTokenURIWithGlobalBaseURI() public {
        vm.prank(minter);
        pets.mint(user);

        string memory uri = pets.tokenURI(0);
        assertEq(uri, "https://api.example.com/0");
    }

    function testTokenURIWithEmptyBaseURI() public {
        vm.prank(admin);
        pets.setBaseURI("");

        vm.prank(minter);
        pets.mint(user);

        string memory uri = pets.tokenURI(0);
        assertEq(uri, "");
    }

    // ==================== Access Control Tests ====================

    function testSupportsInterface() public {
        // ERC721
        assertTrue(pets.supportsInterface(0x80ac58cd));
        // AccessControl
        assertTrue(pets.supportsInterface(0x7965db0b));
    }

    function testAdminCanGrantRoles() public {
        address newMinter = address(0xF);
        vm.startPrank(admin);
        pets.grantRole(pets.MINTER_ROLE(), newMinter);
        vm.stopPrank();

        vm.prank(newMinter);
        pets.mint(user);
        assertEq(pets.ownerOf(0), user);
    }

    function testAdminCanRevokeRoles() public {
        vm.startPrank(admin);
        pets.revokeRole(pets.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.prank(minter);
        vm.expectRevert();
        pets.mint(user);
    }

    // ==================== Regression Tests for Batch 0 Bug ====================

    function testCannotOverlapFrozenBatch0() public {
        // Setup: Create and freeze batch 0 (tokens 0-4)
        vm.startPrank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch0/");
        pets.freezeBatchBaseURI(0);
        vm.stopPrank();

        // Attempt to create overlapping batch that includes token 0
        vm.prank(admin);
        vm.expectRevert(BatchURIFrozen.selector);
        pets.setBatchBaseURI(0, 2, "ipfs://newbatch/");
    }

    function testCannotOverlapFrozenBatch0PartialOverlap() public {
        // Setup: Create and freeze batch 0 (tokens 0-4)
        vm.startPrank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch0/");
        pets.freezeBatchBaseURI(0);
        vm.stopPrank();

        // Attempt to create batch that partially overlaps (tokens 2-6)
        vm.prank(admin);
        vm.expectRevert(BatchURIFrozen.selector);
        pets.setBatchBaseURI(2, 6, "ipfs://overlap/");
    }

    function testGetBatchInfoReturnsEmptyForUnassignedToken() public {
        // Create batch 0 to ensure _batches array has content
        vm.prank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch0/");

        // Query a token that was never assigned to any batch
        BatchInfo memory info = pets.getBatchInfo(100);

        // Should return empty struct
        assertEq(info.startTokenId, 0);
        assertEq(info.endTokenId, 0);
        assertEq(info.baseURI, "");
        assertEq(info.frozen, false);
    }

    function testGetBatchInfoReturnsEmptyWhenNoBatchesExist() public {
        // Query token when no batches have been created at all
        BatchInfo memory info = pets.getBatchInfo(0);

        // Should return empty struct
        assertEq(info.startTokenId, 0);
        assertEq(info.endTokenId, 0);
        assertEq(info.baseURI, "");
        assertEq(info.frozen, false);
    }

    function testBatch0TokensUseBatch0URI() public {
        // Create batch 0
        vm.prank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch0/");

        // Mint tokens
        vm.prank(minter);
        pets.mintBatch(user, 5);

        // Verify tokens 0-4 use batch 0 URI
        assertEq(pets.tokenURI(0), "ipfs://batch0/0");
        assertEq(pets.tokenURI(1), "ipfs://batch0/1");
        assertEq(pets.tokenURI(2), "ipfs://batch0/2");
        assertEq(pets.tokenURI(3), "ipfs://batch0/3");
        assertEq(pets.tokenURI(4), "ipfs://batch0/4");
    }

    function testUnassignedTokensFallbackToGlobalURI() public {
        // Create batch 0 (tokens 0-4)
        vm.prank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch0/");

        // Mint tokens including some outside batch 0
        vm.prank(minter);
        pets.mintBatch(user, 8);

        // Tokens 0-4 should use batch 0 URI
        assertEq(pets.tokenURI(0), "ipfs://batch0/0");
        assertEq(pets.tokenURI(4), "ipfs://batch0/4");

        // Tokens 5-7 should fall back to global URI
        assertEq(pets.tokenURI(5), "https://api.example.com/5");
        assertEq(pets.tokenURI(6), "https://api.example.com/6");
        assertEq(pets.tokenURI(7), "https://api.example.com/7");
    }

    function testCanReassignUnfrozenBatch0() public {
        // Create batch 0 (tokens 0-4) but don't freeze it
        vm.startPrank(admin);
        pets.setBatchBaseURI(0, 4, "ipfs://batch0/");

        // Should be able to reassign tokens from batch 0 to a new batch
        pets.setBatchBaseURI(0, 2, "ipfs://newbatch/");
        vm.stopPrank();

        vm.prank(minter);
        pets.mint(user);

        // Token 0 should now use the new batch URI
        assertEq(pets.tokenURI(0), "ipfs://newbatch/0");
    }
}
