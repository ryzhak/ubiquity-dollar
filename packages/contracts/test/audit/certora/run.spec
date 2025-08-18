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
