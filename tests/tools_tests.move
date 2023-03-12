// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::tools_tests {
	use sui::math;
	use sui::coin::{Coin};
    use std::vector;
	use turbos_clmm::math_u128;

	public fun encode_price_sqrt(reserve1: u64, reserve0: u64): u128 {
		math::sqrt_u128(((reserve1 / reserve0) as u128)) * math_u128::pow(2, 64)
	}

    public fun coin_to_vec<T>(coin: Coin<T>): vector<Coin<T>> {
        let self = vector::empty<Coin<T>>();
        vector::push_back(&mut self, coin);
        self
    }

}