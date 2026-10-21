// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_partner_router_tests {
    use sui::clock::{Self, Clock};
    use sui::coin;
    use sui::test_scenario;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::i32;
    use turbos_clmm::math_tick;
    use turbos_clmm::partner::Partner;
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{Self, AclConfig};
    use turbos_clmm::security_entrypoint_tests::{A, B};
    use turbos_clmm::security_partner_flash_tests::{Self, partner_balance};
    use turbos_clmm::security_position_tests;
    use turbos_clmm::swap_router;

    // Every negative reaches the actual partner-router path. Error location is
    // asserted by the wrapper, not accepted as an arbitrary fixture failure.
    // 0 exact input, 1 exact output, 2 deadline, 3 minimum output, 4 maximum input,
    // 5 paused, 6 zero amount, 7 out-of-bounds price, 8 wrong direction,
    // 9 expired partner, 10 partial exact input, 11 partial exact output,
    // 12 deadline equality, 13 partner start equality, 14 insufficient funding.
    fun run(a_to_b: bool, mode: u8) {
        let s = security_position_tests::liquid();
        let (id, _) = security_partner_flash_tests::partners(&mut s);
        let partner = test_scenario::take_shared_by_id<Partner>(&s, id);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let time = if (mode == 9) 1000000 else if (mode == 13) 0 else 1;
        clock::set_for_testing(&mut clock, time);
        let deadline = if (mode == 2) 0 else if (mode == 12) time else 2000000;
        if (mode == 5) {
            let acl = test_scenario::take_shared<AclConfig>(&s);
            pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
            test_scenario::return_shared(acl);
        };
        let exact_in = !(mode == 1 || mode == 4 || mode == 11);
        let amount = if (mode == 6) 0 else 100000;
        let threshold = if (mode == 3) 18446744073709551615
            else if (mode == 4) 0 else if (exact_in) 0 else 200000;
        let limit = if (mode == 7) 0 else if (mode == 8) {
            if (a_to_b) 18446744073709551617 else 18446744073709551615
        } else if (mode == 10 || mode == 11) {
            math_tick::sqrt_price_from_tick_index(if (a_to_b) i32::neg_from(10) else i32::from(10))
        } else if (a_to_b) 4295048016 else 79226673515401279992447579055;
        let funding = if (mode == 14) 1 else 200000;
        let (before_a, before_b) = pool::get_pool_balance(&p);
        let (a, b) = if (a_to_b) {
            let input = coin::mint_for_testing<A>(funding, test_scenario::ctx(&mut s));
            swap_router::swap_a_b_with_partner(&mut p, &mut partner, input, amount,
                threshold, limit, exact_in, deadline, &clock, &v, test_scenario::ctx(&mut s))
        } else {
            let input = coin::mint_for_testing<B>(funding, test_scenario::ctx(&mut s));
            swap_router::swap_b_a_with_partner(&mut p, &mut partner, input, amount,
                threshold, limit, exact_in, deadline, &clock, &v, test_scenario::ctx(&mut s))
        };
        let (after_a, after_b) = pool::get_pool_balance(&p);
        let fee_a = partner_balance<A>(&partner);
        let fee_b = partner_balance<B>(&partner);
        assert!(after_a + coin::value(&a) + fee_a == before_a + (if (a_to_b) funding else 0), 1000);
        assert!(after_b + coin::value(&b) + fee_b == before_b + (if (a_to_b) 0 else funding), 1001);
        let paid = funding - (if (a_to_b) coin::value(&a) else coin::value(&b));
        let received = if (a_to_b) coin::value(&b) else coin::value(&a);
        assert!(paid > 0 && received > 0, 1002);
        if (exact_in) assert!(paid == amount, 1003) else assert!(received == amount, 1004);
        if (mode == 9) assert!(fee_a == 0 && fee_b == 0, 1005)
        else assert!(if (a_to_b) fee_a > 0 && fee_b == 0 else fee_b > 0 && fee_a == 0, 1006);
        coin::burn_for_testing(a); coin::burn_for_testing(b);
        test_scenario::return_shared(partner); test_scenario::return_shared(p);
        test_scenario::return_shared(clock); test_scenario::return_shared(v);
        test_scenario::end(s);
    }

    #[test] fun a_to_b_exact_input_conserves_all_assets() { run(true, 0); }
    #[test] fun b_to_a_exact_input_conserves_all_assets() { run(false, 0); }
    #[test] fun a_to_b_exact_output_conserves_all_assets() { run(true, 1); }
    #[test] fun b_to_a_exact_output_conserves_all_assets() { run(false, 1); }
    #[test] fun a_to_b_expired_partner_receives_no_fee() { run(true, 9); }
    #[test] fun b_to_a_expired_partner_receives_no_fee() { run(false, 9); }
    #[test] fun a_to_b_deadline_equality_is_accepted() { run(true, 12); }
    #[test] fun b_to_a_deadline_equality_is_accepted() { run(false, 12); }
    #[test] fun a_to_b_partner_start_equality_is_active() { run(true, 13); }
    #[test] fun b_to_a_partner_start_equality_is_active() { run(false, 13); }
    #[test, expected_failure(abort_code = 2, location = turbos_clmm::swap_router)]
    fun a_to_b_expired_deadline_rejects() { run(true, 2); }
    #[test, expected_failure(abort_code = 2, location = turbos_clmm::swap_router)]
    fun b_to_a_expired_deadline_rejects() { run(false, 2); }
    #[test, expected_failure(abort_code = 4, location = turbos_clmm::swap_router)]
    fun a_to_b_minimum_output_rejects() { run(true, 3); }
    #[test, expected_failure(abort_code = 4, location = turbos_clmm::swap_router)]
    fun b_to_a_minimum_output_rejects() { run(false, 3); }
    #[test, expected_failure(abort_code = 5, location = turbos_clmm::swap_router)]
    fun a_to_b_maximum_input_rejects() { run(true, 4); }
    #[test, expected_failure(abort_code = 5, location = turbos_clmm::swap_router)]
    fun b_to_a_maximum_input_rejects() { run(false, 4); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun a_to_b_paused_pool_rejects() { run(true, 5); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun b_to_a_paused_pool_rejects() { run(false, 5); }
    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool)]
    fun a_to_b_zero_amount_rejects() { run(true, 6); }
    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool)]
    fun b_to_a_zero_amount_rejects() { run(false, 6); }
    #[test, expected_failure(abort_code = 19, location = turbos_clmm::pool)]
    fun a_to_b_price_bounds_reject() { run(true, 7); }
    #[test, expected_failure(abort_code = 19, location = turbos_clmm::pool)]
    fun b_to_a_price_bounds_reject() { run(false, 7); }
    #[test, expected_failure(abort_code = 20, location = turbos_clmm::pool)]
    fun a_to_b_wrong_price_direction_rejects() { run(true, 8); }
    #[test, expected_failure(abort_code = 20, location = turbos_clmm::pool)]
    fun b_to_a_wrong_price_direction_rejects() { run(false, 8); }
    #[test, expected_failure(abort_code = 7, location = turbos_clmm::swap_router)]
    fun a_to_b_partial_exact_input_rejects() { run(true, 10); }
    #[test, expected_failure(abort_code = 7, location = turbos_clmm::swap_router)]
    fun b_to_a_partial_exact_input_rejects() { run(false, 10); }
    #[test, expected_failure(abort_code = 7, location = turbos_clmm::swap_router)]
    fun a_to_b_partial_exact_output_rejects() { run(true, 11); }
    #[test, expected_failure(abort_code = 7, location = turbos_clmm::swap_router)]
    fun b_to_a_partial_exact_output_rejects() { run(false, 11); }
    #[test, expected_failure(abort_code = 2, location = sui::balance)]
    fun a_to_b_insufficient_coin_rejects() { run(true, 14); }
    #[test, expected_failure(abort_code = 2, location = sui::balance)]
    fun b_to_a_insufficient_coin_rejects() { run(false, 14); }
}
