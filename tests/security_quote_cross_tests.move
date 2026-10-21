// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_quote_cross_tests {
    use std::bcs;
    use sui::bcs as reader;
    use sui::clock::{Self, Clock};
    use sui::coin;
    use sui::object;
    use sui::test_scenario::{Self, Scenario};
    use sui::transfer;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::i32;
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_fetcher;
    use turbos_clmm::pool_factory::{Self, AclConfig};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::security_entrypoint_tests::{Self, A, B};
    use turbos_clmm::security_position_tests;
    use turbos_clmm::swap_router;

    // Add outer liquidity so a real swap can cross +/-1000 without exhausting
    // all liquidity. Crossing the initialized inner boundary changes active L.
    fun nested(): Scenario {
        let s = security_position_tests::liquid();
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let a = coin::mint_for_testing<A>(1000000, test_scenario::ctx(&mut s));
        let b = coin::mint_for_testing<B>(1000000, test_scenario::ctx(&mut s));
        let (nft, a, b) = position_manager::mint_with_return_(
            &mut p, &mut positions, vector[a], vector[b], 2000, true, 2000, false,
            1000000, 1000000, 0, 0, 1000, &clock, &v, test_scenario::ctx(&mut s),
        );
        assert!(position_manager::get_nft_minted(&positions) == 2, 1200);
        let (_, _, liquidity) = position_manager::get_position_info(&positions, object::id_address(&nft));
        assert!(liquidity > 0, 1201);
        transfer::public_transfer(nft, @0xB);
        coin::burn_for_testing(a); coin::burn_for_testing(b);
        test_scenario::return_shared(p); test_scenario::return_shared(positions);
        test_scenario::return_shared(clock); test_scenario::return_shared(v);
        test_scenario::next_tx(&mut s, @0xB);
        s
    }

    // The first two fields of the deployed ComputeSwapState BCS schema are
    // amount_a/u128 and amount_b/u128. No production getter/test hook is added.
    fun amounts(state: &pool::ComputeSwapState): (u64, u64) {
        let bytes = reader::new(bcs::to_bytes(state));
        let a = reader::peel_u128(&mut bytes); let b = reader::peel_u128(&mut bytes);
        let _ = reader::into_remainder_bytes(bytes);
        ((a as u64), (b as u64))
    }

    // 0 ordinary; 1 actual crossing; 2 zero; 3 invalid bounds; 4 wrong direction;
    // 5 paused; 6 no liquidity; 7 equal price (zero fill is a quote, not a trade).
    fun run(a_to_b: bool, exact_in: bool, mode: u8) {
        let s = if (mode == 1) nested() else if (mode == 6)
            security_entrypoint_tests::setup(15) else security_position_tests::liquid();
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        clock::set_for_testing(&mut clock, 1000);
        let v = test_scenario::take_shared<Versioned>(&s);
        if (mode == 5) {
            let acl = test_scenario::take_shared<AclConfig>(&s);
            pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
            test_scenario::return_shared(acl);
        };
        let amount = if (mode == 2) 0 else if (mode == 1) 1700000 else 100000;
        let limit = if (mode == 3) 0 else if (mode == 4) {
            if (a_to_b) 18446744073709551617 else 18446744073709551615
        } else if (mode == 7) pool::get_pool_sqrt_price(&p)
        else if (a_to_b) 4295048016 else 79226673515401279992447579055;
        let price_before = pool::get_pool_sqrt_price(&p);
        let index_before = pool::get_pool_current_index(&p);
        let (reserve_a_before, reserve_b_before) = pool::get_pool_balance(&p);
        let liquidity_before = pool::get_pool_liquidity(&p);
        let index = if (a_to_b) i32::neg_from(1000) else i32::from(1000);
        let tick_before = if (mode == 1) bcs::to_bytes(pool::get_tick(&p, index)) else vector[];
        let state = pool_fetcher::compute_swap_result(&mut p, a_to_b, amount, exact_in,
            limit, &clock, &v, test_scenario::ctx(&mut s));
        // dry_run suppresses trading/tick updates, NOT reward-clock settlement.
        // Pin that deployed behavior explicitly instead of calling this read-only.
        assert!(pool::get_pool_sqrt_price(&p) == price_before &&
            i32::eq(pool::get_pool_current_index(&p), index_before) &&
            pool::get_pool_liquidity(&p) == liquidity_before, 1202);
        let (reserve_a_after, reserve_b_after) = pool::get_pool_balance(&p);
        assert!(reserve_a_before == reserve_a_after && reserve_b_before == reserve_b_after, 1214);
        assert!(pool::get_pool_reward_last_updated_time_ms(&p) == 1000, 1215);
        let settled_pool = bcs::to_bytes(&p);
        let again = pool_fetcher::compute_swap_result(&mut p, a_to_b, amount, exact_in,
            limit, &clock, &v, test_scenario::ctx(&mut s));
        assert!(settled_pool == bcs::to_bytes(&p), 1216);
        assert!(bcs::to_bytes(&state) == bcs::to_bytes(&again), 1203);
        if (mode == 1) assert!(tick_before == bcs::to_bytes(pool::get_tick(&p, index)), 1204);
        let (quote_a, quote_b) = amounts(&state);
        if (mode == 6 || mode == 7) assert!(quote_a == 0 && quote_b == 0, 1205)
        else {
            let funding = 4000000;
            let (before_a, before_b) = pool::get_pool_balance(&p);
            let (out, refund) = if (a_to_b) {
                let input = coin::mint_for_testing<A>(funding, test_scenario::ctx(&mut s));
                let (out, refund) = swap_router::swap_a_b_with_return_(&mut p, vector[input],
                    (amount as u64), if (exact_in) quote_b else quote_a, limit, exact_in,
                    @0xB, 1000, &clock, &v, test_scenario::ctx(&mut s));
                assert!(coin::value(&out) == quote_b && funding - coin::value(&refund) == quote_a, 1206);
                let out_value = coin::value(&out); let refund_value = coin::value(&refund);
                coin::burn_for_testing(out); coin::burn_for_testing(refund);
                (out_value, refund_value)
            } else {
                let input = coin::mint_for_testing<B>(funding, test_scenario::ctx(&mut s));
                let (out, refund) = swap_router::swap_b_a_with_return_(&mut p, vector[input],
                    (amount as u64), if (exact_in) quote_a else quote_b, limit, exact_in,
                    @0xB, 1000, &clock, &v, test_scenario::ctx(&mut s));
                assert!(coin::value(&out) == quote_a && funding - coin::value(&refund) == quote_b, 1207);
                let out_value = coin::value(&out); let refund_value = coin::value(&refund);
                coin::burn_for_testing(out); coin::burn_for_testing(refund);
                (out_value, refund_value)
            };
            let (after_a, after_b) = pool::get_pool_balance(&p);
            assert!(after_a + (if (a_to_b) refund else out) == before_a + (if (a_to_b) funding else 0), 1208);
            assert!(after_b + (if (a_to_b) out else refund) == before_b + (if (a_to_b) 0 else funding), 1209);
            if (mode == 1) {
                let now = pool::get_pool_current_index(&p);
                assert!(if (a_to_b) i32::lt(now, index) else i32::gte(now, index), 1210);
                assert!(pool::get_pool_liquidity(&p) > 0 && pool::get_pool_liquidity(&p) < liquidity_before, 1211);
                assert!(tick_before != bcs::to_bytes(pool::get_tick(&p, index)), 1212);
                let tick = pool::get_tick(&p, index);
                let (growth_a, growth_b) = pool::get_tick_fee_growth_outside(tick);
                assert!(if (a_to_b) growth_a > 0 else growth_b > 0, 1213);
            };
        };
        test_scenario::return_shared(p); test_scenario::return_shared(clock);
        test_scenario::return_shared(v); test_scenario::end(s);
    }

    #[test] fun a_to_b_exact_input_quote_matches_execution() { run(true, true, 0); }
    #[test] fun b_to_a_exact_input_quote_matches_execution() { run(false, true, 0); }
    #[test] fun a_to_b_exact_output_quote_matches_execution() { run(true, false, 0); }
    #[test] fun b_to_a_exact_output_quote_matches_execution() { run(false, false, 0); }
    #[test] fun a_to_b_exact_input_crosses_initialized_tick() { run(true, true, 1); }
    #[test] fun b_to_a_exact_input_crosses_initialized_tick() { run(false, true, 1); }
    #[test] fun a_to_b_exact_output_crosses_initialized_tick() { run(true, false, 1); }
    #[test] fun b_to_a_exact_output_crosses_initialized_tick() { run(false, false, 1); }
    #[test] fun a_to_b_no_liquidity_quote_has_zero_fill() { run(true, true, 6); }
    #[test] fun b_to_a_no_liquidity_quote_has_zero_fill() { run(false, true, 6); }
    #[test] fun a_to_b_equal_price_quote_has_zero_fill() { run(true, true, 7); }
    #[test] fun b_to_a_equal_price_quote_has_zero_fill() { run(false, true, 7); }
    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool)]
    fun a_to_b_zero_amount_quote_rejects() { run(true, true, 2); }
    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool)]
    fun b_to_a_zero_amount_quote_rejects() { run(false, true, 2); }
    #[test, expected_failure(abort_code = 19, location = turbos_clmm::pool)]
    fun a_to_b_invalid_price_quote_rejects() { run(true, true, 3); }
    #[test, expected_failure(abort_code = 19, location = turbos_clmm::pool)]
    fun b_to_a_invalid_price_quote_rejects() { run(false, true, 3); }
    #[test, expected_failure(abort_code = 20, location = turbos_clmm::pool)]
    fun a_to_b_wrong_direction_quote_rejects() { run(true, true, 4); }
    #[test, expected_failure(abort_code = 20, location = turbos_clmm::pool)]
    fun b_to_a_wrong_direction_quote_rejects() { run(false, true, 4); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun a_to_b_paused_quote_rejects() { run(true, true, 5); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun b_to_a_paused_quote_rejects() { run(false, true, 5); }
}
