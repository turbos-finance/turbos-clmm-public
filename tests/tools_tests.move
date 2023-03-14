// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::tools_tests {
	use sui::coin::{Coin};
    use std::vector;

	const MAX_TICK_INDEX: u32 = 443636;

    public fun coin_to_vec<T>(coin: Coin<T>): vector<Coin<T>> {
        let self = vector::empty<Coin<T>>();
        vector::push_back(&mut self, coin);
        self
    }

}