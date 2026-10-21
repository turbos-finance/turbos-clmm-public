// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_math_guard_tests {
    use sui::test_scenario;
    use turbos_clmm::acl;
    use turbos_clmm::i128;
    use turbos_clmm::math_liquidity;

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::math_liquidity)]
    fun negative_liquidity_delta_cannot_underflow() {
        math_liquidity::add_delta(100, i128::neg_from(101));
    }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::math_liquidity)]
    fun positive_liquidity_delta_cannot_overflow() {
        math_liquidity::add_delta(340282366920938463463374607431768211455, i128::from(1));
    }
    #[test, expected_failure(abort_code = 1, location = turbos_clmm::math_liquidity)]
    fun shifted_liquidity_overflow_is_rejected() {
        math_liquidity::get_amount_a_for_liquidity(18446744073709551616,
            36893488147419103232, 18446744073709551616);
    }
    #[test]
    fun reversed_bounds_preserve_liquidity_and_amounts() {
        let lo = 9223372036854775808; let hi = 36893488147419103232;
        let price = 18446744073709551616;
        let liquidity = math_liquidity::get_liquidity_for_amounts(price, lo, hi, 10000, 20000);
        assert!(liquidity > 0 && liquidity == math_liquidity::get_liquidity_for_amounts(price, hi, lo, 10000, 20000), 1400);
        let (a, b) = math_liquidity::get_amount_for_liquidity(price, lo, hi, liquidity);
        let (reversed_a, reversed_b) = math_liquidity::get_amount_for_liquidity(price, hi, lo, liquidity);
        assert!(a == reversed_a && b == reversed_b && a <= 10000 && b <= 20000, 1401);
        assert!(math_liquidity::add_delta(100, i128::neg_from(100)) == 0, 1402);
    }
    #[test]
    fun removing_absent_role_does_not_grant_or_create_membership() {
        let s = test_scenario::begin(@0xA);
        let acl = acl::new(test_scenario::ctx(&mut s));
        acl::remove_role(&mut acl, @0xB, 127);
        assert!(std::vector::is_empty(&acl::get_members(&acl)), 1403);
        assert!(!acl::has_role(&acl, @0xB, 127) && acl::get_permission(&acl, @0xB) == 0, 1404);
        sui::transfer::public_transfer(acl, @0xA); test_scenario::end(s);
    }
}
