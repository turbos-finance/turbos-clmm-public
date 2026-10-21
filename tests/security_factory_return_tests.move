// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_factory_return_tests {
    use std::option;
    use sui::clock::{Self, Clock};
    use sui::coin;
    use sui::object;
    use sui::test_scenario::{Self, Scenario};
    use sui::transfer;
    use turbos_clmm::fee::Fee;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::fee1000bps::FEE1000BPS;
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolConfig};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft;
    use turbos_clmm::security_entrypoint_tests::{Self, A, B, R};

    // 0 normal; 1 empty A; 2 empty B; 3 slippage A; 4 slippage B;
    // 5 expired; 6 deadline equality; 7 misaligned tick; 8 reversed ticks;
    // 9 tick outside bounds; 10 zero desired amounts; 11 insufficient A;
    // 12 insufficient B; 13 reversed range. Generics also exercise duplicate
    // type/pool and absent tier. Equal range fails earlier in liquidity math.
    fun run<C, D, F>(s: Scenario, mode: u8) {
        let config = test_scenario::take_shared<PoolConfig>(&s);
        let fee = test_scenario::take_immutable<Fee<F>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        clock::set_for_testing(&mut clock, 1);
        let v = test_scenario::take_shared<Versioned>(&s);
        let a = if (mode == 1) vector[] else vector[
            coin::mint_for_testing<C>(if (mode == 11) 1 else 1000000, test_scenario::ctx(&mut s))];
        let b = if (mode == 2) vector[] else vector[
            coin::mint_for_testing<D>(if (mode == 12) 1 else 1000000, test_scenario::ctx(&mut s))];
        let before_minted = position_manager::get_nft_minted(&positions);
        let (nft, left_a, left_b, id) = pool_factory::deploy_pool_and_mint_with_return_(
            &mut config, &fee, 18446744073709551616, &mut positions, a, b,
            if (mode == 7) 1001 else if (mode == 9) 443640 else if (mode == 13) 2000 else 1000,
            !(mode == 8 || mode == 13), 1000, false,
            if (mode == 10) 0 else 1000000, if (mode == 10) 0 else 1000000,
            if (mode == 3) 1000001 else 0, if (mode == 4) 1000001 else 0,
            if (mode == 5) 0 else if (mode == 6) 1 else 1000,
            &clock, &v, test_scenario::ctx(&mut s),
        );
        assert!(position_nft::pool_id(&nft) == id, 1100);
        assert!(option::destroy_some(pool_factory::get_pool_id<C, D, F>(&mut config)) == id, 1101);
        assert!(option::destroy_some(pool_factory::get_pool_id<D, C, F>(&mut config)) == id, 1102);
        assert!(position_manager::get_nft_minted(&positions) == before_minted + 1, 1103);
        let (_, _, liquidity) = position_manager::get_position_info(&positions, object::id_address(&nft));
        assert!(liquidity > 0, 1104);
        let refund_a = coin::value(&left_a); let refund_b = coin::value(&left_b);
        assert!(refund_a < 1000000 && refund_b < 1000000, 1105);
        transfer::public_transfer(nft, @0xB);
        coin::burn_for_testing(left_a); coin::burn_for_testing(left_b);
        test_scenario::return_shared(config); test_scenario::return_immutable(fee);
        test_scenario::return_shared(positions); test_scenario::return_shared(clock);
        test_scenario::return_shared(v);
        test_scenario::next_tx(&mut s, @0xB);
        let p = test_scenario::take_shared_by_id<Pool<C, D, F>>(&s, id);
        let (reserve_a, reserve_b) = pool::get_pool_balance(&p);
        assert!(reserve_a + refund_a == 1000000 && reserve_b + refund_b == 1000000, 1106);
        test_scenario::return_shared(p); test_scenario::end(s);
    }

    fun normal(mode: u8) { run<A, R, FEE500BPS>(security_entrypoint_tests::setup(15), mode); }
    #[test] fun returned_nft_registry_and_reserves_are_bound() { normal(0); }
    #[test] fun deadline_equality_is_accepted() { normal(6); }
    #[test] fun lookup_absent_pool_is_none() {
        let s = security_entrypoint_tests::setup(15);
        let config = test_scenario::take_shared<PoolConfig>(&s);
        assert!(option::is_none(&pool_factory::get_pool_id<A, R, FEE500BPS>(&mut config)), 1107);
        test_scenario::return_shared(config); test_scenario::end(s);
    }
    #[test, expected_failure(abort_code = 4, location = turbos_clmm::pool_factory)]
    fun repeated_coin_type_rejects() { run<A, A, FEE500BPS>(security_entrypoint_tests::setup(15), 0); }
    #[test, expected_failure(abort_code = 5, location = turbos_clmm::pool_factory)]
    fun existing_pool_rejects() { run<A, B, FEE500BPS>(security_entrypoint_tests::setup(15), 0); }
    #[test, expected_failure(abort_code = 5, location = turbos_clmm::pool_factory)]
    fun existing_pool_reverse_order_rejects() { run<B, A, FEE500BPS>(security_entrypoint_tests::setup(15), 0); }
    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun unregistered_fee_tier_rejects() { run<A, R, FEE1000BPS>(security_entrypoint_tests::setup(15), 0); }
    #[test, expected_failure(abort_code = 4, location = turbos_clmm::position_manager)]
    fun empty_a_vector_rejects() { normal(1); }
    #[test, expected_failure(abort_code = 4, location = turbos_clmm::position_manager)]
    fun empty_b_vector_rejects() { normal(2); }
    #[test, expected_failure(abort_code = 5, location = turbos_clmm::position_manager)]
    fun minimum_a_rejects() { normal(3); }
    #[test, expected_failure(abort_code = 5, location = turbos_clmm::position_manager)]
    fun minimum_b_rejects() { normal(4); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun expired_deadline_rejects() { normal(5); }
    #[test, expected_failure(abort_code = 12, location = turbos_clmm::pool)]
    fun misaligned_tick_rejects() { normal(7); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u128)]
    fun equal_ticks_reject_in_liquidity_math() { normal(8); }
    #[test, expected_failure(abort_code = 5, location = turbos_clmm::pool)]
    fun reversed_ticks_reject() { normal(13); }
    #[test, expected_failure(abort_code = 5, location = turbos_clmm::pool)]
    fun tick_outside_bounds_rejects() { normal(9); }
    #[test, expected_failure(abort_code = 1, location = turbos_clmm::pool)]
    fun zero_liquidity_rejects() { normal(10); }
    #[test, expected_failure(abort_code = 2, location = sui::balance)]
    fun insufficient_a_funding_rejects() { normal(11); }
    #[test, expected_failure(abort_code = 2, location = sui::balance)]
    fun insufficient_b_funding_rejects() { normal(12); }
}
