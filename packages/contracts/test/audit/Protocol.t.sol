// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/console2.sol";
import {DiamondTestSetup} from "../diamond/DiamondTestSetup.sol";
import {UbiquityAlgorithmicDollarManager} from "../../src/deprecated/UbiquityAlgorithmicDollarManager.sol";
import {UbiquityGovernance} from "../../src/deprecated/UbiquityGovernance.sol";
import {MockERC20} from "../../src/dollar/mocks/MockERC20.sol";
import {LibStaking} from "../../src/dollar/libraries/LibStaking.sol";

contract ProtocolTest is DiamondTestSetup {
    UbiquityAlgorithmicDollarManager dollarManager;
    UbiquityGovernance rewardToken;
    MockERC20 stakeToken;
    MockERC20 stakeToken2;

    address user = makeAddr("user");

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        dollarManager = new UbiquityAlgorithmicDollarManager(owner);

        vm.prank(owner);
        rewardToken = new UbiquityGovernance(address(dollarManager));

        stakeToken = new MockERC20("STK", "STK", 18);
        stakeToken2 = new MockERC20("STK2", "STK2", 18);

        // staking setup
        vm.startPrank(admin);
        stakingFacet.setGovernancePerBlock(1 ether);
        stakingFacet.setGovernanceTreasuryDivider(5);
        stakingFacet.setStakingRewardToken(address(rewardToken));
        stakingFacet.setStakingStartBlock(block.number);
        vm.stopPrank();

        // owner grants diamond the "UBQ_MINTER_ROLE"
        // NOTICE: in production environment the diamond contract already has the "UBQ_MINTER_ROLE" role
        vm.prank(owner);
        dollarManager.grantRole(keccak256("UBQ_MINTER_ROLE"), address(diamond));

        // admin creates a new staking pool
        vm.startPrank(admin);
        stakingFacet.createStakingPool(
            100, // allocation points
            stakeToken,
            getAvailablePoolIds() // array of pool ids to update
        );
        vm.stopPrank();

        // mint 100 STK tokens to user
        stakeToken.mint(user, 100 ether);

        // mint 100 STK2 tokens to user
        stakeToken2.mint(user, 100 ether);

        // user approves diamond to spend STK tokens
        vm.prank(user);
        stakeToken.approve(address(diamond), type(uint256).max);

        // user approves diamond to spend STK2 tokens
        vm.prank(user);
        stakeToken2.approve(address(diamond), type(uint256).max);
    }

    //==========
    // Public
    //==========

    function testMassUpdateStakingPool_ShouldRefreshRewards() public {
        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        console2.log("Treasury balance (UBQ):", rewardToken.balanceOf(admin));
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet)));

        stakingFacet.massUpdateStakingPools(getAvailablePoolIds());

        console2.log("Treasury balance (UBQ):", rewardToken.balanceOf(admin));
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet)));
    }

    function testStake_ShouldStakeTokens() public {
        console2.log("User balance (STK):", stakeToken.balanceOf(user));
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet)));

        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        console2.log("User balance (STK):", stakeToken.balanceOf(user));
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet)));
    }

    function testUnstake_ShouldUnstakeTokens() public {
        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        console2.log("User balance (STK):", stakeToken.balanceOf(user));
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet)));

        vm.prank(user);
        stakingFacet.unstake(0, 1 ether);

        console2.log("User balance (STK):", stakeToken.balanceOf(user));
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet)));
    }

    function testUnstake_ShouldUnstakeTokensAndHarvestRewards() public {
        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        console2.log("User balance (STK):", stakeToken.balanceOf(user));
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet)));
        console2.log("User balance (UBQ):", rewardToken.balanceOf(user));
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet)));

        // 10 blocks pass
        vm.roll(block.number + 10);

        vm.prank(user);
        stakingFacet.unstake(0, 1 ether);

        console2.log("User balance (STK):", stakeToken.balanceOf(user));
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet)));
        console2.log("User balance (UBQ):", rewardToken.balanceOf(user));
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet)));
    }

    function testUpdateStakingPool_ShouldRefreshRewards() public {
        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        console2.log("Treasury balance (UBQ):", rewardToken.balanceOf(admin));
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet)));

        stakingFacet.updateStakingPool(0);

        console2.log("Treasury balance (UBQ):", rewardToken.balanceOf(admin));
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet)));
    }

    //==============
    // Restricted
    //==============

    function testCreateStakingPool_ShouldCreateNewStakingPool() public {
        vm.startPrank(admin);
        stakingFacet.createStakingPool(
            200, // allocation points
            stakeToken2,
            getAvailablePoolIds() // array of pool ids to update
        );
        vm.stopPrank();

        LibStaking.PoolInfo memory poolInfo = stakingFacet.getStakingPoolInfo(1);
        console2.log(poolInfo.allocationPoints);
    }

    function testSetGovernanceBonusMultiplier_ShouldIncreaseRewards() public {
        vm.startPrank(admin);
        stakingFacet.setGovernanceBonusEndBlock(block.number + 10);
        stakingFacet.setGovernanceBonusMultiplier(2);
        vm.stopPrank();

        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        // 20 blocks pass
        vm.roll(block.number + 20);

        console2.log("User balance (STK):", stakeToken.balanceOf(user)); // 99
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet))); // 1
        console2.log("User balance (UBQ):", rewardToken.balanceOf(user)); // 0
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet))); // 0

        vm.prank(user);
        stakingFacet.unstake(0, 1 ether);

        console2.log("User balance (STK):", stakeToken.balanceOf(user)); // 100
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet))); // 0
        console2.log("User balance (UBQ):", rewardToken.balanceOf(user)); // 30
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet))); // 0
    }

    function testSetGovernancePerBlock_ShouldChangeGovernanceRewardsPerBlock() public {
        vm.prank(admin);
        stakingFacet.setGovernancePerBlock(2 ether);

        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        console2.log("User balance (UBQ):", rewardToken.balanceOf(user)); // 0
        console2.log("Treasury balance (UBQ):", rewardToken.balanceOf(admin)); // 0
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet))); // 0

        vm.prank(user);
        stakingFacet.unstake(0, 1 ether);

        console2.log("User balance (UBQ):", rewardToken.balanceOf(user)); // 20
        console2.log("Treasury balance (UBQ):", rewardToken.balanceOf(admin)); // 4
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet))); // 0
    }

    function testSetGovernanceTreasuryDivider_ShouldMintRewardsToTreasury() public {
        vm.prank(admin);
        stakingFacet.setGovernanceTreasuryDivider(10);

        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        console2.log("Treasury balance (UBQ):", rewardToken.balanceOf(admin)); // 0
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet))); // 0

        vm.prank(user);
        stakingFacet.unstake(0, 1 ether);

        console2.log("Treasury balance (UBQ):", rewardToken.balanceOf(admin)); // 1
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet))); // 0
    }

    function testSetStakingRewardToken_ShouldChangeRewardToken() public {
        vm.prank(admin);
        stakingFacet.setStakingRewardToken(address(stakeToken2));

        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        console2.log("User balance (STK):", stakeToken.balanceOf(user)); // 99
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet))); // 1
        console2.log("User balance (UBQ):", rewardToken.balanceOf(user)); // 0
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet))); // 0
        console2.log("User balance (STK2):", stakeToken2.balanceOf(user)); // 100
        console2.log("Contract balance (STK2):", stakeToken2.balanceOf(address(stakingFacet))); // 0

        vm.prank(user);
        stakingFacet.unstake(0, 1 ether);

        console2.log("User balance (STK):", stakeToken.balanceOf(user)); // 100
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet))); // 0
        console2.log("User balance (UBQ):", rewardToken.balanceOf(user)); // 0
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet))); // 0
        console2.log("User balance (STK2):", stakeToken2.balanceOf(user)); // 110
        console2.log("Contract balance (STK2):", stakeToken2.balanceOf(address(stakingFacet))); // 0
    }

    function testSetStakingStartBlock_ShouldChangeStakingStartBlock() public {
        vm.prank(admin);
        stakingFacet.setStakingStartBlock(block.number + 10);

        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        // 20 blocks pass
        vm.roll(block.number + 20);

        console2.log("User balance (STK):", stakeToken.balanceOf(user)); // 99
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet))); // 1
        console2.log("User balance (UBQ):", rewardToken.balanceOf(user)); // 0
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet))); // 0

        vm.prank(user);
        stakingFacet.unstake(0, 1 ether);

        console2.log("User balance (STK):", stakeToken.balanceOf(user)); // 100
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet))); // 0
        // TOCHECK: actual value is 20 somehow
        console2.log("User balance (UBQ):", rewardToken.balanceOf(user)); // 10
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet))); // 0
    }

    function testUpdateStakingPool_ShouldUpdateStakingPoolSettings() public {
        LibStaking.PoolInfo memory poolInfo = stakingFacet.getStakingPoolInfo(0);
        console2.log(poolInfo.allocationPoints);

        vm.startPrank(admin);
        stakingFacet.updateStakingPool(
            0,
            200,
            getAvailablePoolIds()
        );
        vm.stopPrank();

        poolInfo = stakingFacet.getStakingPoolInfo(0);
        console2.log(poolInfo.allocationPoints);
    }

    //================
    // Test helpers
    //================

    /**
     * Returns array of available pool ids
     */
    function getAvailablePoolIds() public view returns (uint256[] memory) {
        uint256 poolsLength = stakingFacet.getStakingPoolsLength();
        uint256[] memory availablePoolIds = new uint256[](poolsLength);
        for (uint256 i = 0; i < poolsLength; ++i) {
            availablePoolIds[i] = i;
        }
        return availablePoolIds;
    }
}
