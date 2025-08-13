methods {
    function _.mint(address, uint256) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
}

rule accumulatedGovernancePerShareMonotonic(uint256 poolId, method f, env e) filtered {
    f -> !f.isFallback
} {
    LibStaking.PoolInfo poolInfoBefore = getStakingPoolInfo(e, poolId);

    calldataarg args;
    f(e, args);

    LibStaking.PoolInfo poolInfoAfter = getStakingPoolInfo(e, poolId);

    assert 
        poolInfoAfter.accumulatedGovernancePerShare >= poolInfoBefore.accumulatedGovernancePerShare,
        "accumulatedGovernancePerShare must only increase";
}
