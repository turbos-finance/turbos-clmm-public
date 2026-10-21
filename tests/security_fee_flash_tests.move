// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_fee_flash_tests {
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::object;
    use sui::test_scenario;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::fee1000bps::FEE1000BPS;
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{Self, AclConfig};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft::TurbosPositionNFT;
    use turbos_clmm::security_entrypoint_tests::{Self, A, B};
    use turbos_clmm::security_position_tests;
    use turbos_clmm::swap_router;

    const OWNER: address = @0xB;
    const RECIPIENT: address = @0xC;
    const MIN: u128 = 4295048016;
    const MAX: u128 = 79226673515401279992447579055;
    const ALL: u64 = 18446744073709551615;

    fun fees(a_to_b: bool, mode: u8) {
        let s = security_position_tests::liquid();
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        let (_, _, before_l) = position_manager::get_position_info(&positions, object::id_address(&nft));
        let (initial_a, initial_b) = pool::get_pool_balance(&p);
        if (a_to_b) {
            let input = coin::mint_for_testing<A>(100000, test_scenario::ctx(&mut s));
            let (output, left) = swap_router::swap_a_b_with_return_(
                &mut p, vector[input], 100000, 0, MIN, true, OWNER, 1000,
                &clock, &v, test_scenario::ctx(&mut s),
            );
            let (a, b) = pool::get_pool_balance(&p);
            assert!(a + coin::value(&left) == initial_a + 100000, 500);
            assert!(b + coin::value(&output) == initial_b, 501);
            assert!(coin::value(&output) > 0, 502);
            coin::burn_for_testing(output); coin::burn_for_testing(left);
        } else {
            let input = coin::mint_for_testing<B>(100000, test_scenario::ctx(&mut s));
            let (output, left) = swap_router::swap_b_a_with_return_(
                &mut p, vector[input], 100000, 0, MAX, true, OWNER, 1000,
                &clock, &v, test_scenario::ctx(&mut s),
            );
            let (a, b) = pool::get_pool_balance(&p);
            assert!(b + coin::value(&left) == initial_b + 100000, 503);
            assert!(a + coin::value(&output) == initial_a, 504);
            assert!(coin::value(&output) > 0, 505);
            coin::burn_for_testing(output); coin::burn_for_testing(left);
        };
        let (before_a, before_b, fee_a, fee_b, _, _, _, _, _, _, _, _, _) = pool::get_pool_info(&p);
        assert!(if (a_to_b) fee_a > 0 && fee_b == 0 else fee_b > 0 && fee_a == 0, 506);
        assert!(fee_a < before_a && fee_b < before_b, 507);
        if (mode == 1) {
            pool_factory::collect_protocol_fee_v2(&acl, &mut p, ALL, ALL, RECIPIENT,
                &v, test_scenario::ctx(&mut s));
        } else {
            let request_a = if (mode == 2) fee_a / 2 else if (mode == 3) 0 else ALL;
            let request_b = if (mode == 2) fee_b / 2 else if (mode == 3) 0 else ALL;
            let (a, b) = pool_factory::collect_protocol_fee_with_return_v2(
                &acl, &mut p, request_a, request_b, RECIPIENT, &v, test_scenario::ctx(&mut s),
            );
            let amount_a = coin::value(&a); let amount_b = coin::value(&b);
            let expected_a = if (request_a > fee_a) fee_a else request_a;
            let expected_b = if (request_b > fee_b) fee_b else request_b;
            assert!(amount_a == expected_a && amount_b == expected_b, 508);
            let (after_a, after_b, remaining_a, remaining_b, _, _, _, _, _, _, _, _, _) = pool::get_pool_info(&p);
            assert!(after_a + amount_a == before_a && after_b + amount_b == before_b, 509);
            assert!(remaining_a + amount_a == fee_a && remaining_b + amount_b == fee_b, 510);
            coin::burn_for_testing(a); coin::burn_for_testing(b);
            if (mode == 0) {
                // A second maximal withdrawal cannot consume LP principal or replay fees.
                let (a, b) = pool_factory::collect_protocol_fee_with_return_v2(
                    &acl, &mut p, ALL, ALL, RECIPIENT, &v, test_scenario::ctx(&mut s),
                );
                assert!(coin::value(&a) == 0 && coin::value(&b) == 0, 511);
                coin::destroy_zero(a); coin::destroy_zero(b);
                let (a, b) = pool::get_pool_balance(&p);
                assert!(a == before_a - fee_a && b == before_b - fee_b, 512);
            };
        };
        let (_, _, after_l) = position_manager::get_position_info(&positions, object::id_address(&nft));
        assert!(after_l == before_l, 513);
        test_scenario::return_to_sender(&s, nft);
        test_scenario::return_shared(p); test_scenario::return_shared(acl);
        test_scenario::return_shared(v); test_scenario::return_shared(clock);
        test_scenario::return_shared(positions);
        if (mode == 1) {
            test_scenario::next_tx(&mut s, RECIPIENT);
            let a = test_scenario::take_from_sender<Coin<A>>(&s);
            let b = test_scenario::take_from_sender<Coin<B>>(&s);
            assert!(coin::value(&a) == fee_a && coin::value(&b) == fee_b, 514);
            coin::burn_for_testing(a); coin::burn_for_testing(b);
        };
        test_scenario::end(s);
    }

    #[test]
    fun fee_a_full_collection_and_replay_preserve_lp_principal() { fees(true, 0); }
    #[test]
    fun fee_b_full_collection_and_replay_preserve_lp_principal() { fees(false, 0); }
    #[test]
    fun fee_a_entry_transfers_exact_protocol_fee() { fees(true, 1); }
    #[test]
    fun fee_b_entry_transfers_exact_protocol_fee() { fees(false, 1); }
    #[test]
    fun fee_a_partial_collection_conserves_fee_counters_and_reserves() { fees(true, 2); }
    #[test]
    fun fee_b_partial_collection_conserves_fee_counters_and_reserves() { fees(false, 2); }
    #[test]
    fun fee_a_zero_request_preserves_accrued_fees() { fees(true, 3); }
    #[test]
    fun fee_b_zero_request_preserves_accrued_fees() { fees(false, 3); }

    // Flash mode: 0 exact repay, 1 underpay, 2 overpay, 3 wrong pool, 4 pause before,
    // 5 pause after borrow, 6 zero amount, 7 out-of-bounds price, 8 wrong price direction.
    fun flash(a_to_b: bool, mode: u8) {
        let s = security_position_tests::liquid();
        if (mode == 3) security_position_tests::second_pool(&mut s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let (before_a, before_b) = pool::get_pool_balance(&p);
        if (mode == 4) pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
        let limit = if (mode == 7) 0 else if (mode == 8) {
            if (a_to_b) MAX else MIN
        } else if (a_to_b) MIN else MAX;
        let amount = if (mode == 6) 0 else 1000;
        let (out_a, out_b, receipt) = pool::flash_swap(
            &mut p, OWNER, a_to_b, amount, false, limit, &clock, &v,
            test_scenario::ctx(&mut s),
        );
        assert!(if (a_to_b) coin::value(&out_b) == 1000 else coin::value(&out_a) == 1000, 515);
        let (receipt_pool, _, pay) = pool::get_flash_swap_receipt_info(&receipt);
        assert!(receipt_pool == object::id(&p) && pay > 1000, 516);
        let actual_pay = if (mode == 1) pay - 1 else if (mode == 2) pay + 1 else pay;
        let repay_a = coin::mint_for_testing<A>(if (a_to_b) actual_pay else 0, test_scenario::ctx(&mut s));
        let repay_b = coin::mint_for_testing<B>(if (a_to_b) 0 else actual_pay, test_scenario::ctx(&mut s));
        if (mode == 5) pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
        if (mode == 3) {
            let wrong = test_scenario::take_shared<Pool<A, B, FEE1000BPS>>(&s);
            pool::repay_flash_swap(&mut wrong, repay_a, repay_b, receipt, &v);
            test_scenario::return_shared(wrong);
        } else {
            pool::repay_flash_swap(&mut p, repay_a, repay_b, receipt, &v);
            let (after_a, after_b) = pool::get_pool_balance(&p);
            assert!(after_a + coin::value(&out_a) == before_a + (if (a_to_b) pay else 0), 517);
            assert!(after_b + coin::value(&out_b) == before_b + (if (a_to_b) 0 else pay), 518);
        };
        coin::burn_for_testing(out_a); coin::burn_for_testing(out_b);
        test_scenario::return_shared(p); test_scenario::return_shared(acl);
        test_scenario::return_shared(v); test_scenario::return_shared(clock);
        test_scenario::end(s);
    }

    fun router(a_to_b: bool, mode: u8) {
        let s = security_position_tests::liquid();
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        if (mode == 1) clock::set_for_testing(&mut clock, 1);
        if (mode == 2 || mode == 3) {
            pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
            if (mode == 3) pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
        };
        let input = if (mode == 6) 1 else 100000;
        let exact_in = mode != 5;
        let threshold = if (mode == 4) ALL else 0;
        let deadline = if (mode == 1) 0 else 1000;
        if (a_to_b) {
            let a = coin::mint_for_testing<A>(input, test_scenario::ctx(&mut s));
            let (out, left) = swap_router::swap_a_b_with_return_(
                &mut p, vector[a], 10000, threshold, MIN, exact_in, OWNER, deadline,
                &clock, &v, test_scenario::ctx(&mut s),
            );
            assert!(coin::value(&out) > 0, 519);
            coin::burn_for_testing(out); coin::burn_for_testing(left);
        } else {
            let b = coin::mint_for_testing<B>(input, test_scenario::ctx(&mut s));
            let (out, left) = swap_router::swap_b_a_with_return_(
                &mut p, vector[b], 10000, threshold, MAX, exact_in, OWNER, deadline,
                &clock, &v, test_scenario::ctx(&mut s),
            );
            assert!(coin::value(&out) > 0, 520);
            coin::burn_for_testing(out); coin::burn_for_testing(left);
        };
        test_scenario::return_shared(p); test_scenario::return_shared(v);
        test_scenario::return_shared(clock); test_scenario::return_shared(acl);
        test_scenario::end(s);
    }

    #[test]
    fun flash_a_to_b_exact_repayment_conserves_reserves() { flash(true, 0); }

    #[test, expected_failure(abort_code = 25, location = turbos_clmm::pool)]
    fun flash_a_to_b_underpay_rejected() { flash(true, 1); }

    #[test, expected_failure(abort_code = 25, location = turbos_clmm::pool)]
    fun flash_a_to_b_overpay_rejected() { flash(true, 2); }

    #[test, expected_failure(abort_code = 24, location = turbos_clmm::pool)]
    fun flash_a_to_b_wrong_pool_rejected() { flash(true, 3); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun flash_a_to_b_paused_before_rejected() { flash(true, 4); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun flash_a_to_b_paused_repayment_rejected() { flash(true, 5); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool)]
    fun flash_a_to_b_zero_amount_rejected() { flash(true, 6); }

    #[test, expected_failure(abort_code = 19, location = turbos_clmm::pool)]
    fun flash_a_to_b_invalid_price_rejected() { flash(true, 7); }

    #[test, expected_failure(abort_code = 20, location = turbos_clmm::pool)]
    fun flash_a_to_b_wrong_price_direction_rejected() { flash(true, 8); }

    #[test, expected_failure(abort_code = 2, location = turbos_clmm::swap_router)]
    fun router_a_to_b_expired_rejected() { router(true, 1); }

    #[test, expected_failure(abort_code = 4, location = turbos_clmm::swap_router)]
    fun router_a_to_b_slippage_exact_in_rejected() { router(true, 4); }

    #[test, expected_failure(abort_code = 5, location = turbos_clmm::swap_router)]
    fun router_a_to_b_slippage_exact_out_rejected() { router(true, 5); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::swap_router)]
    fun router_a_to_b_insufficient_input_rejected() { router(true, 6); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun router_a_to_b_paused_rejected() { router(true, 2); }

    #[test]
    fun router_a_to_b_resumes_after_unpause() { router(true, 3); }

    #[test]
    fun flash_b_to_a_exact_repayment_conserves_reserves() { flash(false, 0); }

    #[test, expected_failure(abort_code = 25, location = turbos_clmm::pool)]
    fun flash_b_to_a_underpay_rejected() { flash(false, 1); }

    #[test, expected_failure(abort_code = 25, location = turbos_clmm::pool)]
    fun flash_b_to_a_overpay_rejected() { flash(false, 2); }

    #[test, expected_failure(abort_code = 24, location = turbos_clmm::pool)]
    fun flash_b_to_a_wrong_pool_rejected() { flash(false, 3); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun flash_b_to_a_paused_before_rejected() { flash(false, 4); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun flash_b_to_a_paused_repayment_rejected() { flash(false, 5); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool)]
    fun flash_b_to_a_zero_amount_rejected() { flash(false, 6); }

    #[test, expected_failure(abort_code = 19, location = turbos_clmm::pool)]
    fun flash_b_to_a_invalid_price_rejected() { flash(false, 7); }

    #[test, expected_failure(abort_code = 20, location = turbos_clmm::pool)]
    fun flash_b_to_a_wrong_price_direction_rejected() { flash(false, 8); }

    #[test, expected_failure(abort_code = 2, location = turbos_clmm::swap_router)]
    fun router_b_to_a_expired_rejected() { router(false, 1); }

    #[test, expected_failure(abort_code = 4, location = turbos_clmm::swap_router)]
    fun router_b_to_a_slippage_exact_in_rejected() { router(false, 4); }

    #[test, expected_failure(abort_code = 5, location = turbos_clmm::swap_router)]
    fun router_b_to_a_slippage_exact_out_rejected() { router(false, 5); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::swap_router)]
    fun router_b_to_a_insufficient_input_rejected() { router(false, 6); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun router_b_to_a_paused_rejected() { router(false, 2); }

    #[test]
    fun router_b_to_a_resumes_after_unpause() { router(false, 3); }

}
