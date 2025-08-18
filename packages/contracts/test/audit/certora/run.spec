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

//========
// Unit
//========

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
rule unit_setGovernanceBonusMultiplier_MustNotRevert() {
    env e;
    uint256 newGovernanceBonusMultiplier;
    
    setGovernanceBonusMultiplier@withrevert(e, newGovernanceBonusMultiplier);

    assert !lastReverted => hasRole(e, DEFAULT_ADMIN_ROLE(), e.msg.sender), "Method reverts unexpectedly";
}
