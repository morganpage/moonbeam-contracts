// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC1155} from "../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

// Define custom interface for external ERC1155 contract (with mint function)
interface IERC1155Mintable {
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
}

contract StreakSystem is AccessControl {
    // Define the roles
    bytes32 public constant CLAIM_ADMIN_ROLE = keccak256("CLAIM_ADMIN_ROLE");

    uint256 public streakResetTime = 2880 minutes; // defaults to 2 days
    uint256 public streakIncrementTime = 1440 minutes; // defaults to 1 day
    mapping(address => uint256) public streak;
    mapping(address => uint256) public lastClaimed;
    mapping(address => uint256) public points;
    mapping(uint256 => uint256) public milestoneToTokenId;
    mapping(uint256 => uint256) public milestoneToPointReward;
    uint256[] public definedMilestones; // keep track of keys

    IERC1155Mintable public rewardToken;

    event Claimed(
        address indexed user,
        uint256 indexed streak,
        uint256 indexed tokenId
    );
    event EarnedNFT(address indexed user, uint256 indexed tokenId);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CLAIM_ADMIN_ROLE, msg.sender);
    }

    function claim() public {
        _claimFor(msg.sender);
    }

    function claimFor(address user) public onlyRole(CLAIM_ADMIN_ROLE) {
        _claimFor(user);
    }

    function _claimFor(address user) private {
        //Is this the first time the user is claiming or are they over the reset time? If so set streak to 1
        if (
            lastClaimed[user] == 0 ||
            (streakResetTime != 0 &&
                block.timestamp - lastClaimed[user] > streakResetTime)
        ) {
            streak[user] = 1;
        } else {
            require(
                block.timestamp - lastClaimed[user] >= streakIncrementTime,
                "You can't claim yet"
            );
            streak[user]++;
        }
        lastClaimed[user] = block.timestamp;
        // Emit an event to notify the user has claimed
        emit Claimed(user, streak[user], milestoneToTokenId[streak[user]]);

        // Check if the user has reached any token milestones, if so mint the token
        if (milestoneToTokenId[streak[user]] != 0) {
            require(address(rewardToken) != address(0), "Reward token not set");
            // Mint the ERC1155 token to the user
            rewardToken.mint(user, milestoneToTokenId[streak[user]], 1, "");
            emit EarnedNFT(user, milestoneToTokenId[streak[user]]);
        }
        // Check if the user has reached any point milestones, if so add the points
        uint256 applicableReward = getPointReward(streak[user]);
        if (applicableReward != 0) {
            points[user] += applicableReward;
        }
    }

    function getBlockTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function setStreak(
        address user,
        uint256 _streak
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        streak[user] = _streak;
    }

    function setStreakResetTime(
        uint256 _streakResetTime
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        streakResetTime = _streakResetTime;
    }

    function setStreakIncrementTime(
        uint256 _streakIncrementTime
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        streakIncrementTime = _streakIncrementTime;
    }

    function setRewardToken(
        address _rewardToken
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardToken = IERC1155Mintable(_rewardToken);
    }

    //Used for testing
    function claimHoursAgo(
        address user,
        uint256 hoursAgo
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        lastClaimed[user] = block.timestamp - hoursAgo * 1 hours;
    }

    //Get how long before the user can claim again
    function timeUntilCanClaim(address user) public view returns (uint256) {
        if (lastClaimed[user] == 0) {
            return 0;
        }
        if (block.timestamp - lastClaimed[user] >= streakIncrementTime) {
            return 0;
        }
        return streakIncrementTime - (block.timestamp - lastClaimed[user]);
    }

    //Get how long before streak resets
    function timeUntilStreakReset(address user) public view returns (uint256) {
        if (lastClaimed[user] == 0) {
            return 0;
        }
        if (block.timestamp - lastClaimed[user] >= streakResetTime) {
            return 0;
        }
        return streakResetTime - (block.timestamp - lastClaimed[user]);
    }

    function setTokenMilestone(
        uint256 milestone,
        uint256 tokenId
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        milestoneToTokenId[milestone] = tokenId;
    }

    function setPointMilestone(
        uint256 milestone,
        uint256 pointReward
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (milestoneToPointReward[milestone] == 0) {
            definedMilestones.push(milestone);
        }
        milestoneToPointReward[milestone] = pointReward;
    }

    function removeTokenMilestone(
        uint256 milestone
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        delete milestoneToTokenId[milestone];
    }

    function removePointMilestone(
        uint256 milestone
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (milestoneToPointReward[milestone] != 0) {
            delete milestoneToPointReward[milestone];
            // Remove from definedMilestones array
            for (uint256 i = 0; i < definedMilestones.length; i++) {
                if (definedMilestones[i] == milestone) {
                    definedMilestones[i] = definedMilestones[
                        definedMilestones.length - 1
                    ];
                    definedMilestones.pop();
                    break;
                }
            }
        }
    }

    // Function to get the reward for a given milestone
    function getPointReward(uint256 milestone) public view returns (uint256) {
        uint256 applicableReward = 0;
        uint256 closestMilestone = 0;

        for (uint256 i = 0; i < definedMilestones.length; i++) {
            uint256 defined = definedMilestones[i];
            if (defined <= milestone && defined > closestMilestone) {
                closestMilestone = defined;
                applicableReward = milestoneToPointReward[defined];
            }
        }
        return applicableReward;
    }
}
