// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::pool_fetcher {
	use sui::tx_context::{TxContext};
	use sui::clock::{Clock};
	use turbos_clmm::pool::{Self, Pool, ComputeSwapState};
    
    public entry fun compute_swap_result<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        a_to_b: bool,
        amount_specified: u128,
        amount_specified_is_input: bool,
        sqrt_price_limit: u128,
        clock: &Clock,
        ctx: &mut TxContext,
    ): ComputeSwapState {
		pool::compute_swap_result(
			pool,
			a_to_b,
			amount_specified,
			amount_specified_is_input,
			sqrt_price_limit,
			true,
			clock,
			ctx,
		)
	}
}