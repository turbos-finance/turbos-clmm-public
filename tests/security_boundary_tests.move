// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_boundary_tests {
    use sui::balance;
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::object;
    use sui::test_scenario;
    use sui::transfer;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolConfig, PoolFactoryAdminCap, AclConfig};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::reward_manager;
    use turbos_clmm::security_entrypoint_tests::{Self, A, B, R, S};

    const ADMIN: address = @0xA;
    const OPERATOR: address = @0xB;
    const RECIPIENT: address = @0xC;

    fun withdraw(amount: u64, index: u64, repeat: bool) {
        let s = security_entrypoint_tests::setup(2);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let vault = test_scenario::take_shared<PoolRewardVault<R>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let before = balance::value(pool::get_reward_vault(&vault));
        let (pool_a, pool_b) = pool::get_pool_balance(&p);
        reward_manager::remove_reward_v2(
            &acl, &mut p, &mut vault, index, amount, RECIPIENT, &clock, &v,
            test_scenario::ctx(&mut s),
        );
        if (repeat) {
            reward_manager::remove_reward_v2(
                &acl, &mut p, &mut vault, index, amount, RECIPIENT, &clock, &v,
                test_scenario::ctx(&mut s),
            );
        };
        let total = if (repeat) amount * 2 else amount;
        assert!(balance::value(pool::get_reward_vault(&vault)) + total == before, 200);
        let (after_a, after_b) = pool::get_pool_balance(&p);
        assert!(after_a == pool_a && after_b == pool_b, 201);
        test_scenario::return_shared(acl);
        test_scenario::return_shared(v);
        test_scenario::return_shared(p);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(&mut s, RECIPIENT);
        let coin = test_scenario::take_from_sender<Coin<R>>(&s);
        let received = coin::value(&coin);
        coin::burn_for_testing(coin);
        if (repeat) {
            let coin = test_scenario::take_from_sender<Coin<R>>(&s);
            assert!(received + coin::value(&coin) == total, 202);
            coin::burn_for_testing(coin);
        } else {
            assert!(received == total, 203);
        };
        test_scenario::end(s);
    }

    #[test]
    fun reward_withdraw_exact_balance_conserves_assets() { withdraw(100, 0, false); }
    #[test]
    fun reward_withdraw_zero_preserves_vault() { withdraw(0, 0, false); }
    #[test]
    fun reward_withdraw_twice_conserves_assets() { withdraw(40, 0, true); }
    #[test, expected_failure(abort_code = 16, location = turbos_clmm::pool)]
    fun reward_withdraw_over_balance_is_rejected() { withdraw(101, 0, false); }
    #[test, expected_failure(abort_code = 16, location = turbos_clmm::pool)]
    fun reward_withdraw_cannot_replay_full_balance() { withdraw(100, 0, true); }
    #[test, expected_failure(abort_code = 13, location = turbos_clmm::pool)]
    fun reward_withdraw_invalid_index_is_rejected() { withdraw(1, 3, false); }

    fun add_reward(coin_value: u64, amount: u64, index: u64) {
        let s = security_entrypoint_tests::setup(2);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let vault = test_scenario::take_shared<PoolRewardVault<R>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let coin = coin::mint_for_testing<R>(coin_value, test_scenario::ctx(&mut s));
        reward_manager::add_reward_v2(
            &acl, &mut p, &mut vault, index, vector[coin], amount, &clock, &v,
            test_scenario::ctx(&mut s),
        );
        assert!(balance::value(pool::get_reward_vault(&vault)) == 100 + amount, 204);
        test_scenario::return_shared(acl);
        test_scenario::return_shared(v);
        test_scenario::return_shared(p);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(&mut s, OPERATOR);
        if (coin_value > amount) {
            let refund = test_scenario::take_from_sender<Coin<R>>(&s);
            assert!(coin::value(&refund) + amount == coin_value, 205);
            coin::burn_for_testing(refund);
        };
        test_scenario::end(s);
    }

    #[test]
    fun reward_add_refunds_exact_excess() { add_reward(50, 30, 0); }
    #[test]
    fun reward_add_zero_refunds_all_input() { add_reward(50, 0, 0); }
    #[test]
    fun reward_add_exact_input_conserves_assets() { add_reward(50, 50, 0); }
    #[test, expected_failure(abort_code = 13, location = turbos_clmm::pool)]
    fun reward_add_invalid_index_is_rejected() { add_reward(50, 30, 3); }

    #[test, expected_failure(abort_code = 14, location = turbos_clmm::pool)]
    fun reward_withdraw_wrong_vault_is_rejected() {
        let s = security_entrypoint_tests::setup(2);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        reward_manager::init_reward_v2<A, B, FEE500BPS, R>(
            &acl, &mut p, 1, OPERATOR, &v, test_scenario::ctx(&mut s),
        );
        let (wrong_vault_address, _, _, _) = pool::get_reward_info(&p, 1);
        test_scenario::return_shared(acl);
        test_scenario::return_shared(v);
        test_scenario::return_shared(p);
        test_scenario::next_tx(&mut s, OPERATOR);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let wrong = test_scenario::take_shared_by_id<PoolRewardVault<R>>(
            &s, object::id_from_address(wrong_vault_address),
        );
        reward_manager::remove_reward_v2(
            &acl, &mut p, &mut wrong, 0, 0, RECIPIENT, &clock, &v,
            test_scenario::ctx(&mut s),
        );
        test_scenario::return_shared(acl);
        test_scenario::return_shared(v);
        test_scenario::return_shared(p);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(wrong);
        test_scenario::end(s);
    }

    fun invalid_reward_index(action: u8, index: u64) {
        let s = security_entrypoint_tests::setup(2);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        if (action == 0) {
            reward_manager::init_reward_v2<A, B, FEE500BPS, S>(
                &acl, &mut p, index, OPERATOR, &v, test_scenario::ctx(&mut s),
            );
        } else if (action == 1) {
            reward_manager::reset_reward_v2<A, B, FEE500BPS, R>(
                &acl, &mut p, index, &v, test_scenario::ctx(&mut s),
            );
        } else {
            reward_manager::update_reward_emissions_v2(
                &acl, &mut p, index, 1, &clock, &v, test_scenario::ctx(&mut s),
            );
        };
        test_scenario::return_shared(acl);
        test_scenario::return_shared(v);
        test_scenario::return_shared(p);
        test_scenario::return_shared(clock);
        test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 13, location = turbos_clmm::pool)]
    fun reward_init_out_of_range_is_rejected() { invalid_reward_index(0, 3); }
    #[test, expected_failure(abort_code = 13, location = turbos_clmm::pool)]
    fun reward_init_skipped_index_is_rejected() { invalid_reward_index(0, 2); }
    #[test, expected_failure(abort_code = 13, location = turbos_clmm::pool)]
    fun reward_reset_out_of_range_is_rejected() { invalid_reward_index(1, 3); }
    #[test, expected_failure(abort_code = 13, location = turbos_clmm::pool)]
    fun reward_emissions_missing_index_is_rejected() { invalid_reward_index(2, 1); }

    fun fee_rate(value: u32, per_pool: bool) {
        let s = security_entrypoint_tests::setup(1);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let config = test_scenario::take_shared<PoolConfig>(&s);
        if (per_pool) {
            pool_factory::update_pool_fee_protocol_v2(&acl, &mut p, value, &v, test_scenario::ctx(&mut s));
            assert!(pool::get_pool_fee_protocol(&p) == value, 206);
        } else {
            pool_factory::set_fee_protocol_v2(&acl, &mut config, value, &v, test_scenario::ctx(&mut s));
        };
        test_scenario::return_shared(acl);
        test_scenario::return_shared(v);
        test_scenario::return_shared(p);
        test_scenario::return_shared(config);
        test_scenario::end(s);
    }

    #[test]
    fun protocol_fee_zero_is_allowed() { fee_rate(0, false); }
    #[test]
    fun protocol_fee_max_valid_is_allowed() { fee_rate(999999, false); }
    #[test]
    fun pool_protocol_fee_zero_is_allowed() { fee_rate(0, true); }
    #[test]
    fun pool_protocol_fee_max_valid_is_allowed() { fee_rate(999999, true); }
    #[test, expected_failure(abort_code = 1, location = turbos_clmm::pool_factory)]
    fun protocol_fee_full_scale_is_rejected() { fee_rate(1000000, false); }
    #[test, expected_failure(abort_code = 1, location = turbos_clmm::pool_factory)]
    fun pool_protocol_fee_full_scale_is_rejected() { fee_rate(1000000, true); }

    #[test]
    fun current_version_gate_accepts_current_version() {
        let s = security_entrypoint_tests::setup(0);
        let v = test_scenario::take_shared<Versioned>(&s);
        assert!(pool::version(&v) == 18, 207);
        pool::check_version(&v);
        test_scenario::return_shared(v);
        test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 22, location = turbos_clmm::pool)]
    fun upgrade_cannot_reapply_current_version() {
        let s = security_entrypoint_tests::setup(0);
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        pool_factory::upgrade(&cap, &mut v);
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(v);
        test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun pause_blocks_real_position_mint() {
        let s = security_entrypoint_tests::setup(8);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
        let a = coin::mint_for_testing<A>(10000, test_scenario::ctx(&mut s));
        let b = coin::mint_for_testing<B>(10000, test_scenario::ctx(&mut s));
        let (nft, a, b) = position_manager::mint_with_return_(
            &mut p, &mut positions, vector[a], vector[b], 10, true, 10, false,
            10000, 10000, 0, 0, 1000, &clock, &v, test_scenario::ctx(&mut s),
        );
        transfer::public_transfer(nft, OPERATOR);
        coin::burn_for_testing(a);
        coin::burn_for_testing(b);
        test_scenario::return_shared(acl);
        test_scenario::return_shared(v);
        test_scenario::return_shared(p);
        test_scenario::return_shared(positions);
        test_scenario::return_shared(clock);
        test_scenario::end(s);
    }
}
