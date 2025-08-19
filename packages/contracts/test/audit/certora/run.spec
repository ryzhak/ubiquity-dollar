methods {
    function _.mint(address, uint256) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
}

definition DEFAULT_ADMIN_ROLE() returns bytes32 = to_bytes32(0);

//========
// High
//========

// `pool.accumulatedGovernancePerShare` only increases
rule high_accumulatedGovernancePerShareMonotonic(method f) filtered { f -> !f.isFallback } {
    uint256 poolId;    
    env e;

    LibStaking.PoolInfo poolInfoBefore = getStakingPoolInfo(e, poolId);

    calldataarg args;
    f(e, args);

    LibStaking.PoolInfo poolInfoAfter = getStakingPoolInfo(e, poolId);

    assert 
        poolInfoAfter.accumulatedGovernancePerShare >= poolInfoBefore.accumulatedGovernancePerShare,
        "accumulatedGovernancePerShare must only increase";
}

//=====================
// Unit (restricted)
//=====================

// `createStakingPool` updates storage as expected
rule unit_createStakingPool_MustUpdateStorageAsExpected() {
    env e;
    uint256 allocationPoints;
    address lpToken;
    uint256[] poolIdsToUpdate;
    uint256 totalAllocationPointsBefore;
    uint256 totalAllocationPointsAfter;

    // 1 pool already exists
    require(getStakingPoolsLength(e) == 1);

    (_, _, _, _, _, _, totalAllocationPointsBefore, _) = getStakingSettings(e);

    createStakingPool(e, allocationPoints, lpToken, poolIdsToUpdate);

    (_, _, _, _, _, _, totalAllocationPointsAfter, _) = getStakingSettings(e);
    LibStaking.PoolInfo poolInfo = getStakingPoolInfo(e, 1);

    assert totalAllocationPointsAfter == totalAllocationPointsBefore + allocationPoints, "Allocation points inconsistency";
    assert poolInfo.lpToken == lpToken, "Pool token mismatch";
    assert poolInfo.amount == 0, "Pool amount must be 0";
    assert poolInfo.allocationPoints == allocationPoints, "Pool's allocation points mismatch";
    assert poolInfo.accumulatedGovernancePerShare == 0, "Accumulated governance per share must be 0";
}

// `createStakingPool` must not revert unexpectedly
rule unit_createStakingPool_MustNotRevertUnexpectedly() {
    env e;
    uint256 allocationPoints;
    address lpToken;
    uint256[] poolIdsToUpdate;
    uint256 totalAllocationPoints;

    // don't update any pools
    require poolIdsToUpdate.length == 0;
    // prevent overflow
    (_, _, _, _, _, _, totalAllocationPoints, _) = getStakingSettings(e);
    require(totalAllocationPoints + allocationPoints < max_uint256);

    createStakingPool@withrevert(e, allocationPoints, lpToken, poolIdsToUpdate);

    assert 
        lastReverted => (!hasRole(e, DEFAULT_ADMIN_ROLE(), e.msg.sender) || lpToken == 0),
        "Method reverts unexpectedly";
}

// `createStakingPool` does not affect other pools
rule unit_createStakingPool_DoesNotAffectOtherPools() {
    env e;
    uint256 allocationPoints;
    address lpToken;
    uint256[] poolIdsToUpdate;

    // 1 pool already exists
    require(getStakingPoolsLength(e) == 1);
    // don't update other pools
    require(poolIdsToUpdate.length == 0);

    LibStaking.PoolInfo otherPoolInfoBefore = getStakingPoolInfo(e, 0);

    createStakingPool(e, allocationPoints, lpToken, poolIdsToUpdate);

    LibStaking.PoolInfo otherPoolInfoAfter = getStakingPoolInfo(e, 0);

    assert otherPoolInfoBefore == otherPoolInfoAfter, "Other pool must not be affected";
}

// `setGovernanceBonusEndBlock` updates storage as expected
rule unit_setGovernanceBonusEndBlock_MustUpdateStorageAsExpected() {
    env e;
    uint256 newGovernanceBonusEndBlock;
    uint256 updatedGovernanceBonusEndBlock;

    setGovernanceBonusEndBlock(e, newGovernanceBonusEndBlock);

    (_, updatedGovernanceBonusEndBlock, _, _, _, _, _, _) = getStakingSettings(e);

    assert updatedGovernanceBonusEndBlock == newGovernanceBonusEndBlock, "Storage must be updated as expected";
}

// `setGovernanceBonusEndBlock` must not revert unexpectedly
rule unit_setGovernanceBonusEndBlock_MustNotRevertUnexpectedly() {
    env e;
    uint256 newGovernanceBonusEndBlock;

    setGovernanceBonusEndBlock@withrevert(e, newGovernanceBonusEndBlock);

    assert 
        lastReverted => (!hasRole(e, DEFAULT_ADMIN_ROLE(), e.msg.sender) || newGovernanceBonusEndBlock < e.block.number),
        "Method reverts unexpectedly";
}

// `setGovernanceBonusMultiplier()` updates storage as expected
rule unit_setGovernanceBonusMultiplier_MustUpdateStorageAsExpected() {
    env e;
    uint256 newGovernanceBonusMultiplier;
    uint256 updatedGovernanceBonusMultiplier;

    setGovernanceBonusMultiplier(e, newGovernanceBonusMultiplier);

    (_, _, updatedGovernanceBonusMultiplier, _, _, _, _, _) = getStakingSettings(e);

    assert updatedGovernanceBonusMultiplier == newGovernanceBonusMultiplier, "Storage must be updated as expected";
}

// `setGovernanceBonusMultiplier()` must not revert unexpectedly
rule unit_setGovernanceBonusMultiplier_MustNotRevertUnexpectedly() {
    env e;
    uint256 newGovernanceBonusMultiplier;

    setGovernanceBonusMultiplier@withrevert(e, newGovernanceBonusMultiplier);

    assert lastReverted => !hasRole(e, DEFAULT_ADMIN_ROLE(), e.msg.sender), "Method reverts unexpectedly";
}

// `setGovernancePerBlock` updates storage as expected
rule unit_setSetGovernancePerBlock_MustUpdateStorageAsExpected() {
    env e;
    uint256 newGovernancePerBlock;
    uint256 updatedGovernancePerBlock;

    setGovernancePerBlock(e, newGovernancePerBlock);

    (_, _, _, updatedGovernancePerBlock, _, _, _, _) = getStakingSettings(e);

    assert updatedGovernancePerBlock == newGovernancePerBlock, "Storage must be updated as expected";
}

// `setGovernancePerBlock` must not revert unexpectedly
rule unit_setGovernancePerBlock_MustNotRevertUnexpectedly() {
    env e;
    uint256 newGovernancePerBlock;

    setGovernancePerBlock@withrevert(e, newGovernancePerBlock);

    assert 
        lastReverted => (!hasRole(e, DEFAULT_ADMIN_ROLE(), e.msg.sender) || newGovernancePerBlock == 0),
        "Method reverts unexpectedly";
}

// `setGovernanceTreasuryDivider` updates storage as expected
rule unit_setGovernanceTreasuryDivider_MustUpdateStorageAsExpected() {
    env e;
    uint256 newGovernanceTreasuryDivider;
    uint256 updatedGovernanceTreasuryDivider;

    setGovernanceTreasuryDivider(e, newGovernanceTreasuryDivider);

    (_, _, _, _, updatedGovernanceTreasuryDivider, _, _, _) = getStakingSettings(e);

    assert updatedGovernanceTreasuryDivider == newGovernanceTreasuryDivider, "Storage must be updated as expected";
}

// `setGovernanceTreasuryDivider` must not revert unexpectedly
rule unit_setGovernanceTreasuryDivider_MustNotRevertUnexpectedly() {
    env e;
    uint256 newGovernanceTreasuryDivider;

    setGovernanceTreasuryDivider@withrevert(e, newGovernanceTreasuryDivider);

    assert 
        lastReverted => (!hasRole(e, DEFAULT_ADMIN_ROLE(), e.msg.sender) || newGovernanceTreasuryDivider == 0),
        "Method reverts unexpectedly";
}

// `setStakingRewardToken` updates storage as expected
rule unit_setStakingRewardToken_MustUpdateStorageAsExpected() {
    env e;
    address newStakingRewardToken;
    address updatedStakingRewardToken;

    setStakingRewardToken(e, newStakingRewardToken);

    (updatedStakingRewardToken, _, _, _, _, _, _, _) = getStakingSettings(e);

    assert updatedStakingRewardToken == newStakingRewardToken, "Storage must be updated as expected";
}

// `setStakingRewardToken` must not revert unexpectedly
rule unit_setStakingRewardToken_MustNotRevertUnexpectedly() {
    env e;
    address newStakingRewardToken;

    setStakingRewardToken@withrevert(e, newStakingRewardToken);

    assert 
        lastReverted => (!hasRole(e, DEFAULT_ADMIN_ROLE(), e.msg.sender) || newStakingRewardToken == 0),
        "Method reverts unexpectedly";
}

// `setStakingStartBlock` updates storage as expected
rule unit_setStakingStartBlock_MustUpdateStorageAsExpected() {
    env e;
    uint256 newStakingStartBlock;
    uint256 updatedStakingStartBlock;

    setStakingStartBlock(e, newStakingStartBlock);

    (_, _, _, _, _, _, _, updatedStakingStartBlock) = getStakingSettings(e);

    assert updatedStakingStartBlock == newStakingStartBlock, "Storage must be updated as expected";
}

// `setStakingStartBlock` must not revert unexpectedly
rule unit_setStakingStartBlock_MustNotRevertUnexpectedly() {
    env e;
    uint256 newStakingStartBlock;

    setStakingStartBlock@withrevert(e, newStakingStartBlock);

    assert 
        lastReverted => (!hasRole(e, DEFAULT_ADMIN_ROLE(), e.msg.sender) || newStakingStartBlock < e.block.number),
        "Method reverts unexpectedly";
}

// `updateStakingPool` updates storage as expected
rule unit_updateStakingPool_MustUpdateStorageAsExpected() {
    env e;
    uint256 poolId;
    uint256 allocationPoints;
    uint256[] poolIdsToUpdate;
    uint256 totalAllocationPointsBefore;
    uint256 totalAllocationPointsAfter;

    // at least 2 pools exist
    require(poolId > 1);
    require(getStakingPoolsLength(e) == poolId + 1);

    (_, _, _, _, _, _, totalAllocationPointsBefore, _) = getStakingSettings(e);
    LibStaking.PoolInfo poolInfoBefore = getStakingPoolInfo(e, poolId);

    updateStakingPool(e, poolId, allocationPoints, poolIdsToUpdate);

    (_, _, _, _, _, _, totalAllocationPointsAfter, _) = getStakingSettings(e);
    LibStaking.PoolInfo poolInfoAfter = getStakingPoolInfo(e, poolId);

    assert totalAllocationPointsAfter == totalAllocationPointsBefore - poolInfoBefore.allocationPoints + allocationPoints, "Allocation points inconsistency";
    assert poolInfoAfter.allocationPoints == allocationPoints, "Pool's allocation points mismatch";
}

// `updateStakingPool` must not revert unexpectedly
rule unit_updateStakingPool_MustNotRevertUnexpectedly() {
    env e;
    uint256 poolId;
    uint256 allocationPoints;
    uint256[] poolIdsToUpdate;
    uint256 totalAllocationPoints;

    // don't update any pools
    require poolIdsToUpdate.length == 0;
    // prevent overflow
    (_, _, _, _, _, _, totalAllocationPoints, _) = getStakingSettings(e);
    LibStaking.PoolInfo poolInfo = getStakingPoolInfo(e, poolId);
    require(totalAllocationPoints >= poolInfo.allocationPoints);
    require(totalAllocationPoints - poolInfo.allocationPoints + allocationPoints < max_uint256);

    updateStakingPool@withrevert(e, poolId, allocationPoints, poolIdsToUpdate);

    assert 
        lastReverted => (!hasRole(e, DEFAULT_ADMIN_ROLE(), e.msg.sender) || poolId >= getStakingPoolsLength(e)),
        "Method reverts unexpectedly";
}

// `updateStakingPool` does not affect other pools
rule unit_updateStakingPool_DoesNotAffectOtherPools() {
    env e;
    uint256 poolId;
    uint256 allocationPoints;
    uint256[] poolIdsToUpdate;

    // at least 2 pools exist
    require(poolId > 1);
    require(getStakingPoolsLength(e) == poolId + 1);
    // don't update any pools
    require poolIdsToUpdate.length == 0;

    LibStaking.PoolInfo otherPoolInfoBefore = getStakingPoolInfo(e, 0);

    updateStakingPool(e, poolId, allocationPoints, poolIdsToUpdate);

    LibStaking.PoolInfo otherPoolInfoAfter = getStakingPoolInfo(e, 0);

    assert otherPoolInfoBefore == otherPoolInfoAfter, "Other pool must not be affected";
}
