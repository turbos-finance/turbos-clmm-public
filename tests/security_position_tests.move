// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_position_tests {
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::object;
    use sui::test_scenario::{Self, Scenario};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use turbos_clmm::fee::Fee;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::fee1000bps::FEE1000BPS;
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault, Versioned};
    use turbos_clmm::pool_factory::{Self, AclConfig, PoolConfig};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft::TurbosPositionNFT;
    use turbos_clmm::security_entrypoint_tests::{Self, A, B, R};

    const OWNER: address = @0xB;
    const OTHER: address = @0xC;
    const MAX: u64 = 18446744073709551615;

    public fun liquid(): Scenario {
        let s = security_entrypoint_tests::setup(15);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        pool_factory::update_pool_fee_protocol_v2(&acl, &mut p, 250000, &v, test_scenario::ctx(&mut s));
        let a = coin::mint_for_testing<A>(1000000, test_scenario::ctx(&mut s));
        let b = coin::mint_for_testing<B>(1000000, test_scenario::ctx(&mut s));
        let (nft, left_a, left_b) = position_manager::mint_with_return_(
            &mut p, &mut positions, vector[a], vector[b], 1000, true, 1000, false,
            1000000, 1000000, 0, 0, 1000, &clock, &v, test_scenario::ctx(&mut s),
        );
        let (pool_a, pool_b) = pool::get_pool_balance(&p);
        assert!(pool_a > 0 && pool_b > 0, 400);
        assert!(pool_a + coin::value(&left_a) == 1000000, 401);
        assert!(pool_b + coin::value(&left_b) == 1000000, 402);
        let (_, _, liquidity) = position_manager::get_position_info(&positions, object::id_address(&nft));
        assert!(liquidity > 0, 403);
        transfer::public_transfer(nft, OWNER);
        coin::burn_for_testing(left_a);
        coin::burn_for_testing(left_b);
        test_scenario::return_shared(p);
        test_scenario::return_shared(positions);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(v);
        test_scenario::return_shared(acl);
        test_scenario::next_tx(&mut s, OWNER);
        s
    }

    public fun second_pool(s: &mut Scenario) {
        let acl = test_scenario::take_shared<AclConfig>(s);
        let config = test_scenario::take_shared<PoolConfig>(s);
        let fee = test_scenario::take_immutable<Fee<FEE1000BPS>>(s);
        let clock = test_scenario::take_shared<Clock>(s);
        let v = test_scenario::take_shared<Versioned>(s);
        pool_factory::set_fee_tier_v2(&acl, &mut config, &fee, &v, test_scenario::ctx(s));
        pool_factory::deploy_pool<A, B, FEE1000BPS>(&mut config, &fee, 18446744073709551616,
            &clock, &v, test_scenario::ctx(s));
        test_scenario::return_shared(acl);
        test_scenario::return_shared(config);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(v);
        test_scenario::return_immutable(fee);
        test_scenario::next_tx(s, OWNER);
    }

    // mode: 0 normal, 1 expired, 2 paused, 3 pause+resume, 4 excessive liquidity, 5 slippage.
    fun operate<F>(p: &mut Pool<A, B, F>, positions: &mut Positions, nft: &mut TurbosPositionNFT,
        vault: &mut PoolRewardVault<R>, clock: &Clock, v: &Versioned, ctx: &mut TxContext,
        action: u8, mode: u8) {
        let deadline = if (mode == 1) 0 else 1000;
        let min = if (mode == 5) MAX else 0;
        let (before_a, before_b) = pool::get_pool_balance(p);
        let (_, _, before_l) = position_manager::get_position_info(positions, object::id_address(nft));
        if (action == 0) {
            let a = coin::mint_for_testing<A>(1000, ctx);
            let b = coin::mint_for_testing<B>(1000, ctx);
            let (a, b) = position_manager::increase_liquidity_with_return_(
                p, positions, vector[a], vector[b], nft, 1000, 1000, min, min, deadline, clock, v, ctx,
            );
            let (after_a, after_b) = pool::get_pool_balance(p);
            assert!(after_a + coin::value(&a) == before_a + 1000, 404);
            assert!(after_b + coin::value(&b) == before_b + 1000, 405);
            let (_, _, after_l) = position_manager::get_position_info(positions, object::id_address(nft));
            assert!(after_l > before_l, 406);
            coin::burn_for_testing(a); coin::burn_for_testing(b);
        } else if (action == 1) {
            let requested = if (mode == 4) before_l + 1 else before_l / 2;
            let (a, b) = position_manager::decrease_liquidity_with_return_(
                p, positions, nft, requested, min, min, deadline, clock, v, ctx,
            );
            let (after_a, after_b) = pool::get_pool_balance(p);
            assert!(after_a + coin::value(&a) == before_a, 407);
            assert!(after_b + coin::value(&b) == before_b, 408);
            let (_, _, after_l) = position_manager::get_position_info(positions, object::id_address(nft));
            assert!(after_l + requested == before_l, 409);
            coin::burn_for_testing(a); coin::burn_for_testing(b);
        } else if (action == 2) {
            let (a, b) = position_manager::collect_with_return_(
                p, positions, nft, MAX, MAX, OWNER, deadline, clock, v, ctx,
            );
            assert!(coin::value(&a) == 0 && coin::value(&b) == 0, 410);
            let (after_a, after_b) = pool::get_pool_balance(p);
            assert!(after_a == before_a && after_b == before_b, 411);
            coin::destroy_zero(a); coin::destroy_zero(b);
        } else {
            let r = position_manager::collect_reward_with_return_(
                p, positions, nft, vault, 0, MAX, OWNER, deadline, clock, v, ctx,
            );
            coin::burn_for_testing(r);
        };
    }

    fun run(action: u8, mode: u8, wrong_pool: bool) {
        let s = liquid();
        if (wrong_pool) second_pool(&mut s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        let vault = test_scenario::take_shared<PoolRewardVault<R>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        if (mode == 1) clock::set_for_testing(&mut clock, 1);
        if (wrong_pool) {
            let p = test_scenario::take_shared<Pool<A, B, FEE1000BPS>>(&s);
            operate(&mut p, &mut positions, &mut nft, &mut vault, &clock, &v,
                test_scenario::ctx(&mut s), action, mode);
            test_scenario::return_shared(p);
        } else {
            let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
            if (mode == 2 || mode == 3) {
                let acl = test_scenario::take_shared<AclConfig>(&s);
                pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
                assert!(!pool::get_pool_unlocked(&p), 412);
                if (mode == 3) {
                    pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
                    assert!(pool::get_pool_unlocked(&p), 413);
                };
                test_scenario::return_shared(acl);
            };
            operate(&mut p, &mut positions, &mut nft, &mut vault, &clock, &v,
                test_scenario::ctx(&mut s), action, mode);
            test_scenario::return_shared(p);
        };
        test_scenario::return_to_sender(&s, nft);
        test_scenario::return_shared(v);
        test_scenario::return_shared(positions);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(clock);
        test_scenario::end(s);
    }

    #[test]
    fun mint_real_liquidity_conserves_input_and_refunds() { test_scenario::end(liquid()); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::position_manager)]
    fun nft_cannot_burn_before_position_is_cleared() {
        let s = liquid();
        let positions = test_scenario::take_shared<Positions>(&s);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        position_manager::burn<A, B, FEE500BPS>(&mut positions, nft, &v, test_scenario::ctx(&mut s));
        test_scenario::return_shared(positions);
        test_scenario::return_shared(v);
        test_scenario::end(s);
    }

    #[test]
    fun cleared_position_can_exit_and_burn_nft() {
        let s = liquid();
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let (_, _, liquidity) = position_manager::get_position_info(&positions, object::id_address(&nft));
        let (before_a, before_b) = pool::get_pool_balance(&p);
        let (a, b) = position_manager::decrease_liquidity_with_return_(
            &mut p, &mut positions, &mut nft, liquidity, 0, 0, 1000, &clock, &v,
            test_scenario::ctx(&mut s),
        );
        let (after_a, after_b) = pool::get_pool_balance(&p);
        assert!(after_a + coin::value(&a) == before_a && after_b + coin::value(&b) == before_b, 414);
        assert!(pool::get_pool_liquidity(&p) == 0, 415);
        position_manager::burn<A, B, FEE500BPS>(&mut positions, nft, &v, test_scenario::ctx(&mut s));
        coin::burn_for_testing(a); coin::burn_for_testing(b);
        test_scenario::return_shared(p); test_scenario::return_shared(positions);
        test_scenario::return_shared(clock); test_scenario::return_shared(v);
        test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 3, location = sui::test_scenario)]
    fun non_owner_cannot_take_position_nft() {
        let s = liquid();
        test_scenario::next_tx(&mut s, OTHER);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        test_scenario::return_to_sender(&s, nft); test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 3, location = sui::test_scenario)]
    fun old_owner_cannot_take_transferred_position_nft() {
        let s = liquid();
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        transfer::public_transfer(nft, OTHER);
        test_scenario::next_tx(&mut s, OWNER);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        test_scenario::return_to_sender(&s, nft); test_scenario::end(s);
    }

    #[test]
    fun increase_normal_path_succeeds() { run(0, 0, false); }

    #[test, expected_failure(abort_code = 15, location = turbos_clmm::position_manager)]
    fun increase_wrong_pool_rejected() { run(0, 0, true); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun increase_expired_deadline_rejected() { run(0, 1, false); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun increase_paused_pool_rejected() { run(0, 2, false); }

    #[test]
    fun increase_resumes_after_unpause() { run(0, 3, false); }

    #[test]
    fun decrease_normal_path_succeeds() { run(1, 0, false); }

    #[test, expected_failure(abort_code = 15, location = turbos_clmm::position_manager)]
    fun decrease_wrong_pool_rejected() { run(1, 0, true); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun decrease_expired_deadline_rejected() { run(1, 1, false); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun decrease_paused_pool_rejected() { run(1, 2, false); }

    #[test]
    fun decrease_resumes_after_unpause() { run(1, 3, false); }

    #[test]
    fun collect_fee_normal_path_succeeds() { run(2, 0, false); }

    #[test, expected_failure(abort_code = 15, location = turbos_clmm::position_manager)]
    fun collect_fee_wrong_pool_rejected() { run(2, 0, true); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun collect_fee_expired_deadline_rejected() { run(2, 1, false); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun collect_fee_paused_pool_rejected() { run(2, 2, false); }

    #[test]
    fun collect_fee_resumes_after_unpause() { run(2, 3, false); }

    #[test]
    fun collect_reward_normal_path_succeeds() { run(3, 0, false); }

    #[test, expected_failure(abort_code = 15, location = turbos_clmm::position_manager)]
    fun collect_reward_wrong_pool_rejected() { run(3, 0, true); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun collect_reward_expired_deadline_rejected() { run(3, 1, false); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun collect_reward_paused_pool_rejected() { run(3, 2, false); }

    #[test]
    fun collect_reward_resumes_after_unpause() { run(3, 3, false); }

    #[test, expected_failure(abort_code = 9, location = turbos_clmm::position_manager)]
    fun decrease_over_owned_liquidity_rejected() { run(1, 4, false); }
    #[test, expected_failure(abort_code = 5, location = turbos_clmm::position_manager)]
    fun increase_minimum_amount_slippage_rejected() { run(0, 5, false); }
    #[test, expected_failure(abort_code = 5, location = turbos_clmm::position_manager)]
    fun decrease_minimum_amount_slippage_rejected() { run(1, 5, false); }
}
