// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::math_bit_tests {
	use turbos_clmm::math_bit;
	use sui::test_utils::{assert_eq};

	#[test]
	public fun test_least_significant_bit() {
		assert_eq(math_bit::least_significant_bit(1), 0);
		assert_eq(math_bit::least_significant_bit(2), 1);
		assert_eq(math_bit::least_significant_bit(303412046524374704979968), 1);
	}
}