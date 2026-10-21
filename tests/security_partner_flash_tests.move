// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_partner_flash_tests {
    use std::string::{Self, String};
    use std::type_name;
    use sui::bag;
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin;
    use sui::object::{Self, ID};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::fee1000bps::FEE1000BPS;
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap};
    use turbos_clmm::partner::{Self, Partners, Partner, PartnerAdminCap};
    use turbos_clmm::security_position_tests;
    use turbos_clmm::security_entrypoint_tests::{A, B};
    const ADMIN: address = @0xA;
    const OWNER: address = @0xB;
    const OTHER: address = @0xC;

    fun partners(s: &mut Scenario): (ID, ID) {
        test_scenario::next_tx(s, ADMIN);
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(s);
        pool_factory::init_partners(&cap, test_scenario::ctx(s));
        test_scenario::return_to_sender(s, cap);
        test_scenario::next_tx(s, ADMIN);
        let cap = test_scenario::take_from_sender<PartnerAdminCap>(s);
        let list = test_scenario::take_shared<Partners>(s);
        let clock = test_scenario::take_shared<Clock>(s);
        partner::create_partner(&cap, &mut list, string::utf8(b"one"), 1000, 0, 1000,
            OWNER, &clock, test_scenario::ctx(s));
        test_scenario::return_to_sender(s, cap); test_scenario::return_shared(list);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(s, ADMIN);
        let first = test_scenario::most_recent_id_shared<Partner>();
        let first = std::option::destroy_some(first);
        let cap = test_scenario::take_from_sender<PartnerAdminCap>(s);
        let list = test_scenario::take_shared<Partners>(s);
        let clock = test_scenario::take_shared<Clock>(s);
        partner::create_partner(&cap, &mut list, string::utf8(b"two"), 1000, 0, 1000,
            OTHER, &clock, test_scenario::ctx(s));
        test_scenario::return_to_sender(s, cap); test_scenario::return_shared(list);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(s, OWNER);
        (first, std::option::destroy_some(test_scenario::most_recent_id_shared<Partner>()))
    }

    fun partner_balance<T>(p: &Partner): u64 {
        let key = string::from_ascii(type_name::into_string(type_name::get<T>()));
        if (bag::contains<String>(partner::balances(p), key)) {
            balance::value(bag::borrow<String, Balance<T>>(partner::balances(p), key))
        } else 0
    }

    // mode 0 exact repay; 1 wrong partner; 2 wrong pool; 3 underpay; 4 overpay; 5 expired partner.
    fun run(a_to_b: bool, mode: u8) {
        let s = security_position_tests::liquid();
        if (mode == 2) security_position_tests::second_pool(&mut s);
        let (first_id, second_id) = partners(&mut s);
        let p1 = test_scenario::take_shared_by_id<Partner>(&s, first_id);
        let p2 = test_scenario::take_shared_by_id<Partner>(&s, second_id);
        assert!(object::id(&p1) != object::id(&p2), 800);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        if (mode == 5) clock::set_for_testing(&mut clock, 1000000);
        let v = test_scenario::take_shared<Versioned>(&s);
        let (before_a, before_b) = pool::get_pool_balance(&p);
        let (out_a, out_b, receipt) = pool::flash_swap_partner(
            &mut p, &p1, a_to_b, 100000, false,
            if (a_to_b) 4295048016 else 79226673515401279992447579055,
            &clock, &v, test_scenario::ctx(&mut s),
        );
        let pay = pool::flash_swap_pay_amount(&receipt);
        let amount = if (mode == 3) pay - 1 else if (mode == 4) pay + 1 else pay;
        let a = coin::mint_for_testing<A>(if (a_to_b) amount else 0, test_scenario::ctx(&mut s));
        let b = coin::mint_for_testing<B>(if (a_to_b) 0 else amount, test_scenario::ctx(&mut s));
        if (mode == 1) pool::repay_flash_swap_partner(&mut p, &mut p2, a, b, receipt, &v)
        else if (mode == 2) {
            let wrong = test_scenario::take_shared<Pool<A, B, FEE1000BPS>>(&s);
            pool::repay_flash_swap_partner(&mut wrong, &mut p1, a, b, receipt, &v);
            test_scenario::return_shared(wrong);
        } else {
            pool::repay_flash_swap_partner(&mut p, &mut p1, a, b, receipt, &v);
            let (after_a, after_b) = pool::get_pool_balance(&p);
            let partner_a = partner_balance<A>(&p1); let partner_b = partner_balance<B>(&p1);
            assert!(after_a + coin::value(&out_a) + partner_a == before_a + (if (a_to_b) pay else 0), 801);
            assert!(after_b + coin::value(&out_b) + partner_b == before_b + (if (a_to_b) 0 else pay), 802);
            assert!(partner_balance<A>(&p2) == 0 && partner_balance<B>(&p2) == 0, 803);
            if (mode == 5) assert!(partner_a == 0 && partner_b == 0, 804)
            else assert!(if (a_to_b) partner_a > 0 && partner_b == 0 else partner_b > 0 && partner_a == 0, 805);
        };
        coin::burn_for_testing(out_a); coin::burn_for_testing(out_b);
        test_scenario::return_shared(p1); test_scenario::return_shared(p2);
        test_scenario::return_shared(p); test_scenario::return_shared(clock);
        test_scenario::return_shared(v); test_scenario::end(s);
    }

    #[test]
    fun a_to_b_active_fee_conservation() { run(true, 0); }

    #[test]
    fun a_to_b_expired_partner_no_fee() { run(true, 5); }

    #[test, expected_failure(abort_code = 27, location = turbos_clmm::pool)]
    fun a_to_b_wrong_partner() { run(true, 1); }

    #[test, expected_failure(abort_code = 24, location = turbos_clmm::pool)]
    fun a_to_b_wrong_pool() { run(true, 2); }

    #[test, expected_failure(abort_code = 25, location = turbos_clmm::pool)]
    fun a_to_b_underpay() { run(true, 3); }

    #[test, expected_failure(abort_code = 25, location = turbos_clmm::pool)]
    fun a_to_b_overpay() { run(true, 4); }

    #[test]
    fun b_to_a_active_fee_conservation() { run(false, 0); }

    #[test]
    fun b_to_a_expired_partner_no_fee() { run(false, 5); }

    #[test, expected_failure(abort_code = 27, location = turbos_clmm::pool)]
    fun b_to_a_wrong_partner() { run(false, 1); }

    #[test, expected_failure(abort_code = 24, location = turbos_clmm::pool)]
    fun b_to_a_wrong_pool() { run(false, 2); }

    #[test, expected_failure(abort_code = 25, location = turbos_clmm::pool)]
    fun b_to_a_underpay() { run(false, 3); }

    #[test, expected_failure(abort_code = 25, location = turbos_clmm::pool)]
    fun b_to_a_overpay() { run(false, 4); }

}
