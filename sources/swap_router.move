// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::swap_router {
    use turbos_clmm::i128;
    use sui::tx_context::{TxContext};
    use turbos_clmm::pool::{Self, Pool};
	use sui::coin::{Coin};

    const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;
    
    public entry fun swap_a_b<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		coins_a: vector<Coin<CoinTypeA>>, 
		amount_in: u128,
        _amount_out_min: u128,
        sqrt_price_limit: u128,
        recipient: address,
        _deadline: u128,
		ctx: &mut TxContext
    ) {
        let (amount_a, amount_b) = pool::swap(
			pool,
			true,
			i128::from(amount_in),
			sqrt_price_limit,
			ctx
		);
        let amount_a_64 = (i128::abs_u128(amount_a) as u64);
        let amount_b_64 = (i128::abs_u128(amount_b) as u64);

		pool::swap_coin_a_b(
			pool,
			pool::merge_coin(coins_a),
			amount_a_64,
            amount_b_64,
            recipient,
			ctx
		);
    }

    public entry fun swap_a_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
		pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeB, CoinTypeC>,
		coins_a: vector<Coin<CoinTypeA>>, 
		amount_in: u128,
        _amount_out_min: u128,
        sqrt_price_limit: u128,
        recipient: address,
        _deadline: u128,
		ctx: &mut TxContext
    ) {
        //a for b
        let (amount_a, amount_b) = pool::swap(
			pool_a,
			true,
			i128::from(amount_in),
			sqrt_price_limit,
			ctx
		);

        //b for c
        let (_amount_c, amount_d) = pool::swap(
			pool_b,
			true,
			i128::abs(amount_b),
			MIN_SQRT_PRICE_X64 + 1,
			ctx
		);

        let amount_a_64 = (i128::abs_u128(amount_a) as u64);
        let amount_b_64 = (i128::abs_u128(amount_b) as u64);
        let amount_c_64 = (i128::abs_u128(amount_d) as u64);

        pool::swap_coin_a_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
            pool_a,
            pool_b,
            pool::merge_coin(coins_a),
            amount_a_64,
            amount_b_64,
            amount_c_64,
            recipient,
            ctx
        );
    }
}