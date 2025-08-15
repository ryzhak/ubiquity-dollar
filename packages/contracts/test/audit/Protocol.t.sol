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
    MockERC20 rewardToken2;
    MockERC20 stakeToken;
    MockERC20 stakeToken2;

    address user = makeAddr("user");
    address user2 = makeAddr("user2");

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        dollarManager = new UbiquityAlgorithmicDollarManager(owner);

        vm.prank(owner);
        rewardToken = new UbiquityGovernance(address(dollarManager));

        stakeToken = new MockERC20("STK", "STK", 18);
        stakeToken2 = new MockERC20("STK2", "STK2", 6);
        rewardToken2 = new MockERC20("RWD2", "RWD2", 18);

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

        // mint 100 STK tokens to user2
        stakeToken.mint(user2, 100 ether);
        // mint 100 STK2 tokens to user2
        stakeToken2.mint(user2, 100 ether);
        // user2 approves diamond to spend STK tokens
        vm.prank(user2);
        stakeToken.approve(address(diamond), type(uint256).max);
        // user2 approves diamond to spend STK2 tokens
        vm.prank(user2);
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
        // CHECKED: actual value is 20 somehow => expected since `setStakingStartBlock` works only for newly created pools
        console2.log("User balance (UBQ):", rewardToken.balanceOf(user)); // 20
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

    //=========
    // Other
    //=========

    /**
     * Scenario:
     * 1. User stakes 1 STK
     * 2. 10 blocks passed
     * 3. User2 stakes 1 STK
     * 4. 10 blocks passed
     * 5. Pool is refreshed
     * 
     * At this point:
     * - `accumulatedGovernancePerShare`: `15e12` (amount of tokens a single user would've got per 1 staked token 
     * if he staked from the beginning of the staking pool)
     * - `user.rewardDebt`: `0` (user staked from the beginning of the staking pool)
     * - `user2.rewardDebt`: `10e18` (user2 staked in the middle of the staking period hence he is not eligible for
     * the full 15 tokens reward, we calculate `rewardDebt` as `amount * accumulatedGovernancePerShare = 1 * 10` so it 
     * looked like user2 already got rewards)
     */
    function testCheckHowAccumulatedGovernancePerShareWorks() public {
        LibStaking.PoolInfo memory poolInfo = stakingFacet.getStakingPoolInfo(0);
        LibStaking.UserInfo memory userInfo = stakingFacet.getStakingUserInfo(0, user);
        LibStaking.UserInfo memory userInfo2 = stakingFacet.getStakingUserInfo(0, user2);

        console2.log("accumulatedGovernancePerShare:", poolInfo.accumulatedGovernancePerShare);
        console2.log("user rewardDebt:", userInfo.rewardDebt);
        console2.log("user2 rewardDebt:", userInfo2.rewardDebt);

        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        vm.prank(user2);
        stakingFacet.stake(0, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        stakingFacet.updateStakingPool(0);

        poolInfo = stakingFacet.getStakingPoolInfo(0);
        userInfo = stakingFacet.getStakingUserInfo(0, user);
        userInfo2 = stakingFacet.getStakingUserInfo(0, user2);
        console2.log("accumulatedGovernancePerShare:", poolInfo.accumulatedGovernancePerShare);
        console2.log("user rewardDebt:", userInfo.rewardDebt);
        console2.log("user2 rewardDebt:", userInfo2.rewardDebt);
    }

    function testCreateStakingPool_AffectsCalculations_IfMassUpdateIsNotCalled() public {
        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        vm.startPrank(admin);
        stakingFacet.createStakingPool(
            300, // allocation points
            stakeToken,
            getEmptyPoolIds() // array of pool ids to update
        );
        vm.stopPrank();

        vm.prank(user2);
        stakingFacet.stake(1, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        console2.log("User balance (UBQ):", rewardToken.balanceOf(user)); // 0
        console2.log("User2 balance (UBQ):", rewardToken.balanceOf(user2)); // 0

        vm.prank(user);
        stakingFacet.unstake(0, 1 ether);
        vm.prank(user2);
        stakingFacet.unstake(1, 1 ether);

        console2.log("User balance (UBQ) :", rewardToken.balanceOf(user)); // expected: 12.5, got `20.0 / 4 = 5.0`
        console2.log("User2 balance (UBQ):", rewardToken.balanceOf(user2)); // 7.5
    }

    function testSetStakingRewardToken_ShouldNotAffectCalculations() public {
        vm.startPrank(admin);

        vm.stopPrank();

        vm.prank(user);
        stakingFacet.stake(0, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        vm.startPrank(admin);
        stakingFacet.createStakingPool(
            300, // allocation points
            stakeToken,
            getAvailablePoolIds() // array of pool ids to update
        );
        vm.stopPrank();

        vm.prank(user2);
        stakingFacet.stake(1, 1 ether);

        // 10 blocks pass
        vm.roll(block.number + 10);

        vm.startPrank(admin);
        stakingFacet.updateStakingPool(
            1, // pool id
            100, // allocation points
            getAvailablePoolIds() // array of pool ids to update
        );

        stakingFacet.setStakingRewardToken(address(rewardToken2));

        vm.stopPrank();

        // 10 blocks pass
        vm.roll(block.number + 10);

        stakingFacet.updateStakingPool(0);
        stakingFacet.updateStakingPool(1);

        // mint additional 20 tokens for solvency
        rewardToken2.mint(address(stakingFacet), 20 ether);

        console2.log("User balance (UBQ):", rewardToken.balanceOf(user));
        console2.log("User2 balance (UBQ):", rewardToken.balanceOf(user2));
        console2.log("User balance (RWD2):", rewardToken2.balanceOf(user));
        console2.log("User2 balance (RWD2):", rewardToken2.balanceOf(user2));
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet)));
        console2.log("Contract balance (RWD2):", rewardToken2.balanceOf(address(stakingFacet)));

        vm.prank(user);
        stakingFacet.unstake(0, 1 ether);
        vm.prank(user2);
        stakingFacet.unstake(1, 1 ether);

        console2.log("User balance (UBQ) :", rewardToken.balanceOf(user)); // 17.5
        console2.log("User2 balance (UBQ):", rewardToken.balanceOf(user2)); // 12.5
        console2.log("User balance (RWD2):", rewardToken2.balanceOf(user));
        console2.log("User2 balance (RWD2):", rewardToken2.balanceOf(user2));
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet)));
        console2.log("Contract balance (RWD2):", rewardToken2.balanceOf(address(stakingFacet)));
    }

    //===========
    // Fuzzing
    //===========

    /// forge-config: default.fuzz.runs = 5120
    function testFuzz_ShouldGetRewards_IfAmountAndBlocksPassedNotZero(
        uint allocationPointsPool2, 
        uint amount, 
        uint blocksPassed
    ) public {
        allocationPointsPool2 = bound(allocationPointsPool2, 0, 100_000);
        blocksPassed = bound(blocksPassed, 1, 2628000 * 50); // 50 years
        amount = bound(amount, 1, 1e26); // change to 1e30 to get counterexample

        console2.log("allocationPointsPool2:", allocationPointsPool2);
        console2.log("amount:", amount);
        console2.log("blocksPassed:", blocksPassed);

        // mint stake tokens to users 
        deal(address(stakeToken), user, amount);
        deal(address(stakeToken2), user2, amount);

        // admin creates 2nd staking pool
        vm.startPrank(admin);
        stakingFacet.createStakingPool(
            allocationPointsPool2, // allocation points
            stakeToken2,
            getAvailablePoolIds() // array of pool ids to update
        );
        vm.stopPrank();

        // before staking
        assertEq(rewardToken.balanceOf(user), 0);
        assertEq(rewardToken.balanceOf(user2), 0);
        assertEq(rewardToken.balanceOf(address(stakingFacet)), 0);
        assertEq(stakeToken.balanceOf(user), amount);
        assertEq(stakeToken.balanceOf(user2), 100 ether);
        assertEq(stakeToken.balanceOf(address(stakingFacet)), 0);
        assertEq(stakeToken2.balanceOf(user), 100 ether);
        assertEq(stakeToken2.balanceOf(user2), amount);
        assertEq(stakeToken2.balanceOf(address(stakingFacet)), 0);

        // users stake tokens
        vm.prank(user);
        stakingFacet.stake(0, amount);
        vm.prank(user2);
        stakingFacet.stake(1, amount);

        vm.roll(block.number + blocksPassed);

        // before unstaking
        assertEq(rewardToken.balanceOf(user), 0);
        assertEq(rewardToken.balanceOf(user2), 0);
        assertEq(rewardToken.balanceOf(address(stakingFacet)), 0);
        assertEq(stakeToken.balanceOf(user), 0);
        assertEq(stakeToken.balanceOf(user2), 100 ether);
        assertEq(stakeToken.balanceOf(address(stakingFacet)), amount);
        assertEq(stakeToken2.balanceOf(user), 100 ether);
        assertEq(stakeToken2.balanceOf(user2), 0);
        assertEq(stakeToken2.balanceOf(address(stakingFacet)), amount);

        console2.log("Pending rewards(user):", stakingFacet.getPendingStakingRewards(0, user));
        console2.log("Pending rewards(user2):", stakingFacet.getPendingStakingRewards(1, user2));

        // users unstake tokens
        vm.prank(user);
        stakingFacet.unstake(0, amount);
        vm.prank(user2);
        stakingFacet.unstake(1, amount);

        assertGt(rewardToken.balanceOf(user), 0);

        console2.log("======");
        console2.log("User balance (UBQ) :", rewardToken.balanceOf(user));
        console2.log("User2 balance (UBQ):", rewardToken.balanceOf(user2));
        console2.log("Contract balance (UBQ):", rewardToken.balanceOf(address(stakingFacet)));
        console2.log("User balance (STK) :", stakeToken.balanceOf(user));
        console2.log("User2 balance (STK):", stakeToken.balanceOf(user2));
        console2.log("Contract balance (STK):", stakeToken.balanceOf(address(stakingFacet)));
        console2.log("User balance (STK2) :", stakeToken2.balanceOf(user));
        console2.log("User2 balance (STK2):", stakeToken2.balanceOf(user2));
        console2.log("Contract balance (STK2):", stakeToken2.balanceOf(address(stakingFacet)));
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

    /**
     * Returns array with empty pool ids
     */
    function getEmptyPoolIds() public view returns (uint256[] memory) {
        uint256[] memory availablePoolIds = new uint256[](0);
        return availablePoolIds;
    }
}
