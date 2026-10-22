// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_fee_tier_tests {
    use std::option;
    use sui::clock::Clock;
    use sui::test_scenario;
    use sui::transfer;
    use turbos_clmm::fee::{Self, Fee};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{Self, AclConfig, PoolConfig};
    use turbos_clmm::security_entrypoint_tests::{Self, A, B};

    struct SECURITY_FEE_TIER_TESTS has drop {}
    struct NotWitness has drop {}

    // Real OTW + real authorized factory entry. Accepted boundary tiers must
    // also deploy a pool and preserve both values, not merely avoid an abort.
    fun tier(fee_value: u32, spacing: u32, duplicate: bool) {
        let s = security_entrypoint_tests::setup(1);
        let fee = fee::create_fee(
            SECURITY_FEE_TIER_TESTS {}, fee_value, spacing, test_scenario::ctx(&mut s),
        );
        assert!(fee::get_fee(&fee) == fee_value, 800);
        assert!(fee::get_tick_spacing(&fee) == spacing, 801);
        transfer::public_freeze_object(fee);
        test_scenario::next_tx(&mut s, @0xB);
        let fee = test_scenario::take_immutable<Fee<SECURITY_FEE_TIER_TESTS>>(&s);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let config = test_scenario::take_shared<PoolConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        pool_factory::set_fee_tier_v2(&acl, &mut config, &fee, &v, test_scenario::ctx(&mut s));
        if (duplicate) {
            pool_factory::set_fee_tier_v2(&acl, &mut config, &fee, &v, test_scenario::ctx(&mut s));
        };
        pool_factory::deploy_pool<A, B, SECURITY_FEE_TIER_TESTS>(
            &mut config, &fee, 18446744073709551616, &clock, &v, test_scenario::ctx(&mut s),
        );
        assert!(option::is_some(&pool_factory::get_pool_id<A, B, SECURITY_FEE_TIER_TESTS>(&mut config)), 802);
        test_scenario::return_immutable(fee);
        test_scenario::return_shared(acl);
        test_scenario::return_shared(config);
        test_scenario::return_shared(v);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(&mut s, @0xB);
        let p = test_scenario::take_shared<Pool<A, B, SECURITY_FEE_TIER_TESTS>>(&s);
        assert!(pool::get_pool_fee(&p) == fee_value, 803);
        assert!(pool::get_pool_tick_spacing(&p) == spacing, 804);
        test_scenario::return_shared(p);
        test_scenario::end(s);
    }

    #[test]
    fun zero_fee_is_allowed_and_deployable() { tier(0, 1, false); }
    #[test]
    fun highest_fee_is_allowed_and_deployable() { tier(999999, 1, false); }
    #[test]
    fun smallest_spacing_is_allowed_and_deployable() { tier(500, 1, false); }
    #[test]
    fun highest_spacing_is_allowed_and_deployable() { tier(500, 16383, false); }
    #[test]
    fun both_highest_values_are_allowed_and_deployable() { tier(999999, 16383, false); }
    #[test, expected_failure(abort_code = 1, location = turbos_clmm::pool_factory)]
    fun fee_equal_to_denominator_is_rejected() { tier(1000000, 1, false); }
    #[test, expected_failure(abort_code = 1, location = turbos_clmm::pool_factory)]
    fun maximum_u32_fee_is_rejected() { tier(4294967295, 1, false); }
    #[test, expected_failure(abort_code = 2, location = turbos_clmm::pool_factory)]
    fun zero_spacing_is_rejected() { tier(500, 0, false); }
    #[test, expected_failure(abort_code = 2, location = turbos_clmm::pool_factory)]
    fun spacing_at_exclusive_upper_bound_is_rejected() { tier(500, 16384, false); }
    #[test, expected_failure(abort_code = 3, location = turbos_clmm::pool_factory)]
    fun duplicate_tier_type_is_rejected() { tier(500, 10, true); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::fee)]
    fun ordinary_drop_type_is_not_a_one_time_witness() {
        let s = test_scenario::begin(@0xB);
        let fee = fee::create_fee(NotWitness {}, 500, 10, test_scenario::ctx(&mut s));
        transfer::public_freeze_object(fee);
        test_scenario::end(s);
    }
}
