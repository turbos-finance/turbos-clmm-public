// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_partner_tests {
    use std::string;
    use sui::bag;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self, Scenario};
    use sui::transfer;
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap};
    use turbos_clmm::partner::{Self, Partners, Partner, PartnerCap, PartnerAdminCap};

    const ADMIN: address = @0xA;
    const OWNER: address = @0xB;
    const OTHER: address = @0xC;
    struct R has drop {}
    struct S has drop {}

    fun setup(rate: u64, start: u64, end: u64, name: vector<u8>): Scenario {
        let s = test_scenario::begin(ADMIN);
        pool_factory::init_for_testing(test_scenario::ctx(&mut s));
        let clock = clock::create_for_testing(test_scenario::ctx(&mut s));
        clock::set_for_testing(&mut clock, 100000);
        clock::share_for_testing(clock);
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(&s);
        pool_factory::init_partners(&cap, test_scenario::ctx(&mut s));
        test_scenario::return_to_sender(&s, cap);
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PartnerAdminCap>(&s);
        let partners = test_scenario::take_shared<Partners>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        partner::create_partner(
            &cap, &mut partners, string::utf8(name), rate, start, end, OWNER,
            &clock, test_scenario::ctx(&mut s),
        );
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(partners);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(&mut s, OWNER);
        s
    }

    fun check_create(rate: u64, start: u64, end: u64, name: vector<u8>) {
        let s = setup(rate, start, end, name);
        let p = test_scenario::take_shared<Partner>(&s);
        assert!(partner::ref_fee_rate(&p) == rate, 300);
        assert!(partner::start_time(&p) == start && partner::end_time(&p) == end, 301);
        assert!(partner::name(&p) == string::utf8(b"partner"), 302);
        let cap = test_scenario::take_from_sender<PartnerCap>(&s);
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(p);
        test_scenario::end(s);
    }

    #[test]
    fun create_partner_with_admin_cap_succeeds() { check_create(100, 10, 200, b"partner"); }
    #[test]
    fun create_partner_zero_rate_succeeds() { check_create(0, 10, 200, b"partner"); }
    #[test]
    fun create_partner_max_valid_rate_succeeds() { check_create(9999, 10, 200, b"partner"); }
    #[test]
    fun create_partner_at_end_boundary_matches_deployed_behavior() { check_create(100, 10, 100, b"partner"); }
    #[test, expected_failure(abort_code = 2, location = turbos_clmm::partner)]
    fun create_partner_invalid_rate_rejected() { check_create(10000, 10, 200, b"partner"); }
    #[test, expected_failure(abort_code = 3, location = turbos_clmm::partner)]
    fun create_partner_empty_name_rejected() { check_create(100, 10, 200, b""); }
    #[test, expected_failure(abort_code = 4, location = turbos_clmm::partner)]
    fun create_partner_equal_start_end_rejected() { check_create(100, 200, 200, b"partner"); }
    #[test, expected_failure(abort_code = 4, location = turbos_clmm::partner)]
    fun create_partner_past_end_rejected() { check_create(100, 10, 99, b"partner"); }

    fun update(rate: u64, start: u64, end: u64, update_time: bool) {
        let s = setup(100, 10, 200, b"partner");
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PartnerAdminCap>(&s);
        let p = test_scenario::take_shared<Partner>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        if (update_time) {
            partner::update_time_range(&cap, &mut p, start, end, &clock, test_scenario::ctx(&mut s));
            assert!(partner::start_time(&p) == start && partner::end_time(&p) == end, 303);
        } else {
            partner::update_ref_fee_rate(&cap, &mut p, rate, test_scenario::ctx(&mut s));
            assert!(partner::ref_fee_rate(&p) == rate, 304);
        };
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(p);
        test_scenario::return_shared(clock);
        test_scenario::end(s);
    }

    #[test]
    fun update_rate_zero_succeeds() { update(0, 0, 0, false); }
    #[test]
    fun update_rate_max_valid_succeeds() { update(9999, 0, 0, false); }
    #[test, expected_failure(abort_code = 2, location = turbos_clmm::partner)]
    fun update_rate_full_scale_rejected() { update(10000, 0, 0, false); }
    #[test]
    fun update_time_valid_succeeds() { update(0, 100, 201, true); }
    #[test, expected_failure(abort_code = 4, location = turbos_clmm::partner)]
    fun update_time_equal_start_end_rejected() { update(0, 200, 200, true); }
    #[test, expected_failure(abort_code = 4, location = turbos_clmm::partner)]
    fun update_time_end_now_rejected() { update(0, 10, 100, true); }

    #[test]
    fun fee_rate_active_interval_has_inclusive_start_exclusive_end() {
        let s = setup(123, 100, 200, b"partner");
        let p = test_scenario::take_shared<Partner>(&s);
        assert!(partner::current_ref_fee_rate(&p, 99) == 0, 305);
        assert!(partner::current_ref_fee_rate(&p, 100) == 123, 306);
        assert!(partner::current_ref_fee_rate(&p, 199) == 123, 307);
        assert!(partner::current_ref_fee_rate(&p, 200) == 0, 308);
        test_scenario::return_shared(p);
        test_scenario::end(s);
    }

    public fun funded(): Scenario {
        let s = setup(100, 10, 200, b"partner");
        let p = test_scenario::take_shared<Partner>(&s);
        let a = coin::mint_for_testing<R>(70, test_scenario::ctx(&mut s));
        let b = coin::mint_for_testing<R>(30, test_scenario::ctx(&mut s));
        partner::receive_ref_fee(&mut p, coin::into_balance(a));
        partner::receive_ref_fee(&mut p, coin::into_balance(b));
        assert!(bag::length(partner::balances(&p)) == 1, 309);
        test_scenario::return_shared(p);
        test_scenario::next_tx(&mut s, OWNER);
        s
    }

    fun claim(repeat: bool, wrong_coin: bool, transfer_cap: bool) {
        let s = funded();
        if (transfer_cap) {
            let cap = test_scenario::take_from_sender<PartnerCap>(&s);
            transfer::public_transfer(cap, OTHER);
            test_scenario::next_tx(&mut s, OTHER);
        };
        let cap = test_scenario::take_from_sender<PartnerCap>(&s);
        let p = test_scenario::take_shared<Partner>(&s);
        if (wrong_coin) {
            partner::claim_ref_fee<S>(&cap, &mut p, test_scenario::ctx(&mut s));
        } else {
            partner::claim_ref_fee<R>(&cap, &mut p, test_scenario::ctx(&mut s));
        };
        assert!(bag::length(partner::balances(&p)) == 0, 310);
        if (repeat) partner::claim_ref_fee<R>(&cap, &mut p, test_scenario::ctx(&mut s));
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(p);
        test_scenario::next_tx(&mut s, if (transfer_cap) OTHER else OWNER);
        let received = test_scenario::take_from_sender<Coin<R>>(&s);
        assert!(coin::value(&received) == 100, 311);
        coin::burn_for_testing(received);
        test_scenario::end(s);
    }

    #[test]
    fun cap_owner_claims_merged_exact_balance() { claim(false, false, false); }
    #[test]
    fun new_cap_owner_can_claim_after_transfer() { claim(false, false, true); }
    #[test, expected_failure(abort_code = 6, location = turbos_clmm::partner)]
    fun duplicate_claim_is_rejected() { claim(true, false, false); }
    #[test, expected_failure(abort_code = 6, location = turbos_clmm::partner)]
    fun claim_nonexistent_coin_is_rejected() { claim(false, true, false); }

    #[test, expected_failure(abort_code = 5, location = turbos_clmm::partner)]
    fun wrong_partner_cap_cannot_claim_another_partner() {
        let s = funded();
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PartnerAdminCap>(&s);
        let partners = test_scenario::take_shared<Partners>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        partner::create_partner(&cap, &mut partners, string::utf8(b"other"), 100, 10, 200,
            OTHER, &clock, test_scenario::ctx(&mut s));
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(partners);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(&mut s, OWNER);
        let wrong_cap = test_scenario::take_from_sender<PartnerCap>(&s);
        // The newest shared Partner is the second one, whereas OWNER holds the first cap.
        let second = test_scenario::take_shared<Partner>(&s);
        assert!(partner::name(&second) == string::utf8(b"other"), 312);
        partner::claim_ref_fee<R>(&wrong_cap, &mut second, test_scenario::ctx(&mut s));
        test_scenario::return_to_sender(&s, wrong_cap);
        test_scenario::return_shared(second);
        test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 1, location = turbos_clmm::partner)]
    fun duplicate_name_registration_is_rejected() {
        let s = setup(100, 10, 200, b"partner");
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PartnerAdminCap>(&s);
        let partners = test_scenario::take_shared<Partners>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        partner::create_partner(&cap, &mut partners, string::utf8(b"partner"), 100, 10, 200,
            OTHER, &clock, test_scenario::ctx(&mut s));
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(partners);
        test_scenario::return_shared(clock);
        test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 3, location = sui::test_scenario)]
    fun non_owner_cannot_take_partner_admin_cap() {
        let s = setup(100, 10, 200, b"partner");
        let cap = test_scenario::take_from_sender<PartnerAdminCap>(&s);
        test_scenario::return_to_sender(&s, cap);
        test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 3, location = sui::test_scenario)]
    fun old_owner_cannot_take_transferred_partner_cap() {
        let s = funded();
        let cap = test_scenario::take_from_sender<PartnerCap>(&s);
        transfer::public_transfer(cap, OTHER);
        test_scenario::next_tx(&mut s, OWNER);
        let cap = test_scenario::take_from_sender<PartnerCap>(&s);
        test_scenario::return_to_sender(&s, cap);
        test_scenario::end(s);
    }
}
