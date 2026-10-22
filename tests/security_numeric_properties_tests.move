// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_numeric_properties_tests {
    use turbos_clmm::full_math_u32;
    use turbos_clmm::full_math_u64;
    use turbos_clmm::full_math_u128;
    use turbos_clmm::math_u64;
    use turbos_clmm::math_u128;
    use turbos_clmm::math_u256;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::math_swap;
    const Q64: u128 = 18446744073709551616;
    const U64_MAX: u64 = 18446744073709551615;
    const U128_MAX: u128 = 340282366920938463463374607431768211455;

    // Independent quotient/remainder oracle. "round" is nearest (ties up),
    // intentionally distinct from ceil; do not assert these are interchangeable.
    fun oracle(a: u128, b: u128, d: u128): (u128, u128, u128) {
        let product = (a as u256) * (b as u256);
        let quotient = product / (d as u256);
        let remainder = product % (d as u256);
        ((quotient as u128),
            ((quotient + (if (remainder * 2 >= (d as u256)) 1 else 0)) as u128),
            ((quotient + (if (remainder > 0) 1 else 0)) as u128))
    }
    fun check32(a: u32, b: u32, d: u32) {
        let (floor, nearest, ceil) = oracle((a as u128), (b as u128), (d as u128));
        assert!((full_math_u32::full_mul(a, b) as u256) == (a as u256) * (b as u256), 1700);
        assert!((full_math_u32::mul_div_floor(a, b, d) as u128) == floor, 1701);
        assert!((full_math_u32::mul_div_round(a, b, d) as u128) == nearest, 1702);
        assert!((full_math_u32::mul_div_ceil(a, b, d) as u128) == ceil, 1703);
        assert!(floor <= nearest && nearest <= ceil && ceil - floor <= 1, 1704);
    }
    fun check64(a: u64, b: u64, d: u64) {
        let (floor, nearest, ceil) = oracle((a as u128), (b as u128), (d as u128));
        assert!((full_math_u64::full_mul(a, b) as u256) == (a as u256) * (b as u256), 1705);
        assert!((full_math_u64::mul_div_floor(a, b, d) as u128) == floor, 1706);
        assert!((full_math_u64::mul_div_round(a, b, d) as u128) == nearest, 1707);
        assert!((full_math_u64::mul_div_ceil(a, b, d) as u128) == ceil, 1708);
    }
    fun check128(a: u128, b: u128, d: u128) {
        let (floor, nearest, ceil) = oracle(a, b, d);
        assert!(full_math_u128::full_mul(a, b) == (a as u256) * (b as u256), 1709);
        assert!(full_math_u128::mul_div_floor(a, b, d) == floor, 1710);
        assert!(full_math_u128::mul_div_round(a, b, d) == nearest, 1711);
        assert!(full_math_u128::mul_div_ceil(a, b, d) == ceil, 1712);
    }
    #[test]
    fun u32_full_math_matches_wider_oracle() {
        let a = 0;
        while (a <= 20) { let d = 1; while (d <= 11) {
            check32(a, 7, d); d = d + 1;
        }; a = a + 1; };
        check32(4294967295, 4294967295, 4294967295);
        assert!(full_math_u32::mul_shr(4294967295, 4294967295, 32) == 4294967294, 1713);
        assert!(full_math_u32::mul_shl(7, 9, 2) == 252, 1714);
    }
    #[test]
    fun u64_full_math_matches_wider_oracle() {
        let a = 0;
        while (a <= 20) { let d = 1; while (d <= 11) {
            check64(a, 7, d); d = d + 1;
        }; a = a + 1; };
        check64(U64_MAX, U64_MAX, U64_MAX);
        assert!(full_math_u64::mul_shr(U64_MAX, U64_MAX, 64) == U64_MAX - 1, 1715);
        assert!(full_math_u64::mul_shl(7, 9, 2) == 252, 1716);
    }
    #[test]
    fun u128_full_math_matches_wider_oracle() {
        let a = 0;
        while (a <= 20) { let d = 1; while (d <= 11) {
            check128(a, 7, d); d = d + 1;
        }; a = a + 1; };
        check128(U128_MAX, U128_MAX, U128_MAX);
        assert!(full_math_u128::mul_shr(U128_MAX, U128_MAX, 128) == U128_MAX - 1, 1717);
        assert!(full_math_u128::mul_shl(7, 9, 2) == 252, 1718);
    }
    #[test]
    fun u64_wrapping_subtraction_and_carry_match_wider_oracle() {
        let values = vector[0, 1, 2, U64_MAX / 2, U64_MAX - 1, U64_MAX];
        let i = 0;
        while (i < 6) { let j = 0; while (j < 6) {
            let a = *std::vector::borrow(&values, i); let b = *std::vector::borrow(&values, j);
            let (difference, borrow) = math_u64::overflowing_sub(a, b);
            let expected = ((((a as u128) + 18446744073709551616 - (b as u128)) % 18446744073709551616) as u64);
            assert!(difference == expected && borrow == (a < b) && math_u64::wrapping_sub(a, b) == expected, 1719);
            let (sum, carry) = math_u64::carry_add(a, b, 1);
            let total = (a as u128) + (b as u128) + 1;
            assert!((sum as u128) == total % 18446744073709551616 && (carry as u128) == total / 18446744073709551616, 1720);
            j = j + 1;
        }; i = i + 1; };
    }
    #[test]
    fun u128_wrapping_subtraction_and_halves_round_trip() {
        let values = vector[0, 1, 2, Q64, U128_MAX / 2, U128_MAX];
        let i = 0;
        while (i < 6) { let j = 0; while (j < 6) {
            let a = *std::vector::borrow(&values, i); let b = *std::vector::borrow(&values, j);
            let (difference, borrow) = math_u128::overflowing_sub(a, b);
            let expected = ((((a as u256) + (1u256 << 128) - (b as u256)) % (1u256 << 128)) as u128);
            assert!(difference == expected && borrow == (a < b) && math_u128::wrapping_sub(a, b) == expected, 1721);
            assert!(math_u128::from_lo_hi(math_u128::lo(a), math_u128::hi(a)) == a, 1722);
            assert!(math_u128::hi_u128(a) == (a >> 64) && math_u128::lo_u128(a) == a % Q64, 1723);
            assert!(math_u128::min(a, b) <= math_u128::max(a, b), 1724);
            j = j + 1;
        }; i = i + 1; };
    }
    #[test]
    fun checked_division_rounding_has_less_than_one_unit_error() {
        let n = 0;
        while (n <= 30) { let d = 1; while (d <= 9) {
            let floor = math_u128::checked_div_round(n, d, false);
            let ceil = math_u128::checked_div_round(n, d, true);
            assert!(floor == n / d && ceil == floor + (if (n % d == 0) 0 else 1), 1725);
            d = d + 1;
        }; n = n + 1; };
        assert!(math_u128::checked_div_round(U128_MAX, U128_MAX, true) == 1, 1726);
    }
    #[test]
    fun u256_division_and_checked_shift_boundaries() {
        let (q, r) = math_u256::div_mod((1u256 << 255) + 17, 37);
        assert!(q * 37 + r == (1u256 << 255) + 17 && r < 37, 1727);
        let limit = 1u256 << 192;
        let (valid, overflow) = math_u256::checked_shlw(limit - 1);
        assert!(!overflow && valid == (limit - 1) << 64, 1728);
        let (invalid, overflow) = math_u256::checked_shlw(limit);
        assert!(overflow && invalid == 0, 1729);
        assert!(math_u256::shrw(math_u256::shlw(123)) == 123, 1730);
    }
    #[test]
    fun amount_a_rounding_matches_independent_rational_oracle() {
        let prices = vector[4295048016, Q64 - 1, Q64, Q64 + 1, 79226673515401279992447579055];
        let i = 0;
        while (i < 4) {
            let lo = *std::vector::borrow(&prices, i); let hi = *std::vector::borrow(&prices, i + 1);
            let l = 1000000000000;
            let numerator = (l as u256) * ((hi - lo) as u256) * (Q64 as u256);
            let denominator = (hi as u256) * (lo as u256);
            let floor = ((numerator / denominator) as u128);
            let ceil = (((numerator + denominator - 1) / denominator) as u128);
            assert!(math_sqrt_price::get_amount_a_delta_(lo, hi, l, false) == floor, 1731);
            assert!(math_sqrt_price::get_amount_a_delta_(lo, hi, l, true) == ceil, 1732);
            assert!(math_sqrt_price::get_amount_a_delta_(hi, lo, l, true) == ceil, 1733);
            i = i + 1;
        };
    }
    #[test]
    fun amount_b_floor_and_deployed_nearest_mode_match_oracle() {
        let lo = Q64; let l = 11;
        let deltas = vector[0, 1, Q64 / 4, Q64 / 2, Q64 - 1, Q64];
        let i = 0;
        while (i < 6) {
            let delta = *std::vector::borrow(&deltas, i);
            let (floor, nearest, _) = oracle(l, delta, Q64);
            assert!(math_sqrt_price::get_amount_b_delta_(lo, lo + delta, l, false) == floor, 1734);
            // The deployed true mode calls mul_div_round (nearest), not ceil.
            assert!(math_sqrt_price::get_amount_b_delta_(lo, lo + delta, l, true) == nearest, 1735);
            assert!(math_sqrt_price::get_amount_b_delta_(lo + delta, lo, l, true) == nearest, 1736);
            i = i + 1;
        };
    }
    #[test]
    fun next_price_zero_and_large_amount_boundaries() {
        assert!(math_sqrt_price::get_next_sqrt_price(Q64, 1000000, 0, true, true) == Q64, 1737);
        assert!(math_sqrt_price::get_next_sqrt_price(Q64, 1000000, 0, false, false) == Q64, 1738);
        let l = 1u128 << 80; let amount = 1u128 << 65;
        let expected = 1u128 << 49;
        assert!(math_sqrt_price::get_next_sqrt_price(Q64, l, amount, true, false) == Q64 + expected, 1739);
        assert!(math_sqrt_price::get_next_sqrt_price(Q64, l, amount, false, true) == Q64 - expected, 1740);
        let (price, input, output, fee) = math_swap::compute_swap(Q64, Q64 + 1000, 0, 100, true, 500);
        assert!(price == Q64 + 1000 && input == 0 && output == 0 && fee == 0, 1741);
    }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u32)]
    fun u32_floor_zero_denominator_rejects() { full_math_u32::mul_div_floor(1, 1, 0); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u32)]
    fun u32_nearest_zero_denominator_rejects() { full_math_u32::mul_div_round(1, 1, 0); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u32)]
    fun u32_ceil_zero_denominator_rejects() { full_math_u32::mul_div_ceil(1, 1, 0); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u64)]
    fun u64_floor_zero_denominator_rejects() { full_math_u64::mul_div_floor(1, 1, 0); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u64)]
    fun u64_nearest_zero_denominator_rejects() { full_math_u64::mul_div_round(1, 1, 0); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u64)]
    fun u64_ceil_zero_denominator_rejects() { full_math_u64::mul_div_ceil(1, 1, 0); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u128)]
    fun u128_floor_zero_denominator_rejects() { full_math_u128::mul_div_floor(1, 1, 0); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u128)]
    fun u128_nearest_zero_denominator_rejects() { full_math_u128::mul_div_round(1, 1, 0); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u128)]
    fun u128_ceil_zero_denominator_rejects() { full_math_u128::mul_div_ceil(1, 1, 0); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u32)]
    fun u32_floor_narrowing_overflow_rejects() { full_math_u32::mul_div_floor(4294967295, 2, 1); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u32)]
    fun u32_nearest_narrowing_overflow_rejects() { full_math_u32::mul_div_round(4294967295, 2, 1); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u32)]
    fun u32_ceil_narrowing_overflow_rejects() { full_math_u32::mul_div_ceil(4294967295, 2, 1); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u64)]
    fun u64_floor_narrowing_overflow_rejects() { full_math_u64::mul_div_floor(U64_MAX, 2, 1); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u64)]
    fun u64_nearest_narrowing_overflow_rejects() { full_math_u64::mul_div_round(U64_MAX, 2, 1); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u64)]
    fun u64_ceil_narrowing_overflow_rejects() { full_math_u64::mul_div_ceil(U64_MAX, 2, 1); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u128)]
    fun u128_floor_narrowing_overflow_rejects() { full_math_u128::mul_div_floor(U128_MAX, 2, 1); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u128)]
    fun u128_nearest_narrowing_overflow_rejects() { full_math_u128::mul_div_round(U128_MAX, 2, 1); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::full_math_u128)]
    fun u128_ceil_narrowing_overflow_rejects() { full_math_u128::mul_div_ceil(U128_MAX, 2, 1); }
    #[test, expected_failure(abort_code = 0, location = turbos_clmm::math_u64)]
    fun u64_checked_add_overflow_rejects() { math_u64::wrapping_add(U64_MAX, 1); }
    #[test, expected_failure(abort_code = 0, location = turbos_clmm::math_u64)]
    fun u64_checked_mul_overflow_rejects() { math_u64::wrapping_mul(U64_MAX, 2); }
    #[test, expected_failure(abort_code = 0, location = turbos_clmm::math_u128)]
    fun u128_checked_add_overflow_rejects() { math_u128::wrapping_add(U128_MAX, 1); }
    #[test, expected_failure(abort_code = 0, location = turbos_clmm::math_u128)]
    fun u128_checked_mul_overflow_rejects() { math_u128::wrapping_mul(U128_MAX, 2); }
    #[test, expected_failure(abort_code = 0, location = turbos_clmm::math_u64)]
    fun invalid_carry_rejects() { math_u64::carry_add(0, 0, 2); }
    #[test, expected_failure(abort_code = 1, location = turbos_clmm::math_u128)]
    fun checked_round_zero_denominator_rejects() { math_u128::checked_div_round(1, 0, true); }
    #[test, expected_failure(arithmetic_error, location = turbos_clmm::math_u256)]
    fun div_mod_zero_denominator_rejects() { math_u256::div_mod(1, 0); }
    #[test, expected_failure(abort_code = 0, location = turbos_clmm::math_sqrt_price)]
    fun zero_amount_a_price_rejects() { math_sqrt_price::get_amount_a_delta_(0, Q64, 1, true); }
    #[test, expected_failure(abort_code = 0, location = turbos_clmm::math_sqrt_price)]
    fun exact_output_cannot_exhaust_virtual_b_reserve() { math_sqrt_price::get_next_sqrt_price(Q64, 1, 1, false, true); }
}
