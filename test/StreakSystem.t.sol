// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/StreakSystem.sol";

contract MockERC1155 is IERC1155Mintable {
    mapping(address => mapping(uint256 => uint256)) public minted;

    event Mint(address indexed to, uint256 indexed id, uint256 amount, bytes data);

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external override {
        minted[to][id] += amount;
        emit Mint(to, id, amount, data);
    }
}

contract StreakSystemTest is Test {
    StreakSystem streak;
    MockERC1155 mock1155;
    address admin = address(0xA);
    address claimAdmin = address(0xB);
    address user = address(0xC);

    function setUp() public {
        vm.startPrank(admin);
        streak = new StreakSystem();
        mock1155 = new MockERC1155();
        streak.grantRole(streak.CLAIM_ADMIN_ROLE(), claimAdmin);
        streak.setRewardToken(address(mock1155));
        vm.stopPrank();
    }

    function testAdminCanSetMilestones() public {
        vm.prank(admin);
        streak.setTokenMilestone(3, 42);
        vm.prank(admin);
        streak.setPointMilestone(2, 100);
        assertEq(streak.milestoneToTokenId(3), 42);
        assertEq(streak.milestoneToPointReward(2), 100);
    }

    function testAdminCanRemoveMilestones() public {
        vm.prank(admin);
        streak.setPointMilestone(2, 100);
        vm.prank(admin);
        streak.removePointMilestone(2);
        assertEq(streak.milestoneToPointReward(2), 0);
    }

    function testClaimFirstTimeSetsStreakTo1() public {
        vm.prank(user);
        streak.claim();
        assertEq(streak.streak(user), 1);
    }

    function testClaimIncrementsStreak() public {
        vm.prank(user);
        streak.claim();
        vm.warp(block.timestamp + streak.streakIncrementTime());
        vm.prank(user);
        streak.claim();
        assertEq(streak.streak(user), 2);
    }

    function testClaimResetsStreakAfterResetTime() public {
        vm.prank(user);
        streak.claim();
        vm.warp(block.timestamp + streak.streakResetTime() + 1);
        vm.prank(user);
        streak.claim();
        assertEq(streak.streak(user), 1);
    }

    function testClaimForByClaimAdmin() public {
        vm.prank(claimAdmin);
        streak.claimFor(user);
        assertEq(streak.streak(user), 1);
    }

    function testClaimForByNonClaimAdminFails() public {
        vm.expectRevert();
        streak.claimFor(user);
    }

    function testTokenMilestoneMintsERC1155() public {
        vm.prank(admin);
        streak.setTokenMilestone(1, 99);
        vm.prank(user);
        streak.claim();
        assertEq(mock1155.minted(user, 99), 1);
    }

    function testNoMintIfRewardTokenNotSet() public {
        StreakSystem s2 = new StreakSystem();
        vm.prank(admin);
        s2.grantRole(s2.DEFAULT_ADMIN_ROLE(), admin);
        s2.setTokenMilestone(1, 99);
        vm.prank(user);
        vm.expectRevert("Reward token not set");
        s2.claim();
    }

    function testPointMilestoneAwardsPoints() public {
        vm.prank(admin);
        streak.setPointMilestone(1, 50);
        vm.prank(user);
        streak.claim();
        assertEq(streak.points(user), 50);
    }

    function testTimeUntilCanClaim() public {
        vm.prank(user);
        streak.claim();
        assertEq(streak.timeUntilCanClaim(user), streak.streakIncrementTime());
    }

    function testTimeUntilStreakReset() public {
        vm.prank(user);
        streak.claim();
        assertEq(streak.timeUntilStreakReset(user), streak.streakResetTime());
    }
}
