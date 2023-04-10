// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::swap_router {
    use turbos_clmm::i128;
    use sui::tx_context::{TxContext};
    use turbos_clmm::pool::{Self, Pool};
	use sui::coin::{Coin};
    use sui::clock::{Self, Clock};

    const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;

    const ECoinsVectorMustBeEmpty: u64 = 1;
    const ETransactionToOld: u64 = 2;
    const ETooLittleReceived: u64 = 3; 
    
    public entry fun swap_a_b<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		coins_a: vector<Coin<CoinTypeA>>, 
		amount: u64,
        amount_out_min: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
		ctx: &mut TxContext
    ) {
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a, amount_b) = pool::swap(
			pool,
            recipient,
			true,
			if(is_exact_in) i128::from((amount as u128)) else i128::neg_from((amount as u128)),
			sqrt_price_limit,
            clock,
			ctx
		);
        let amount_a_64 = (i128::abs_u128(amount_a) as u64);
        let amount_b_64 = (i128::abs_u128(amount_b) as u64);
        assert!(amount_b_64 >= amount_out_min, ETooLittleReceived);

		pool::swap_coin_a_b(
			pool,
			pool::merge_coin(coins_a),
			amount_a_64,
            amount_b_64,
            recipient,
			ctx
		);
    }

    public entry fun swap_b_a<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		coins_b: vector<Coin<CoinTypeB>>, 
		amount: u64,
        amount_out_min: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
		ctx: &mut TxContext
    ) {
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a, amount_b) = pool::swap(
			pool,
            recipient,
			false,
			if(is_exact_in) i128::from((amount as u128)) else i128::neg_from((amount as u128)),
			sqrt_price_limit,
            clock,
			ctx
		);
        let amount_a_64 = (i128::abs_u128(amount_b) as u64);
        let amount_b_64 = (i128::abs_u128(amount_a) as u64);
        assert!(amount_b_64 >= amount_out_min, ETooLittleReceived);

		pool::swap_coin_b_a(
			pool,
			pool::merge_coin(coins_b),
			amount_a_64,
            amount_b_64,
            recipient,
			ctx
		);
    }

    // swap a to b to c
    public entry fun swap_a_b_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
		pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
		coins_a: vector<Coin<CoinTypeA>>, 
		amount: u64,
        amount_out_min: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
		ctx: &mut TxContext
    ) {
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a_64, amount_b_64, amount_c_64);

        if (is_exact_in) {
            let (step1_in, step1_out) = pool::swap(
			    pool_a,
                recipient,
			    true,
			    i128::from((amount as u128)),
			    sqrt_price_limit,
                clock,
			    ctx
		    );

            let (_step2_in, step2_out) = pool::swap(
			    pool_b,
                recipient,
			    true,
			    i128::abs(step1_out),
			    MIN_SQRT_PRICE_X64 + 1,
                clock,
			    ctx
		    );

            amount_a_64 = (i128::abs_u128(step1_in) as u64);
            amount_b_64 = (i128::abs_u128(step1_out) as u64);
            amount_c_64 = (i128::abs_u128(step2_out) as u64);
        } else {
            //exact_out
            let (step2_in, step2_out) = pool::swap(
			    pool_b,
                recipient,
			    true,
			    i128::neg_from((amount as u128)),
			    MIN_SQRT_PRICE_X64 + 1,
                clock,
			    ctx
		    );

            let (step1_in, step1_out) = pool::swap(
			    pool_a,
                recipient,
			    true,
			    i128::neg_from(i128::as_u128(step2_in)),
			    sqrt_price_limit,
                clock,
			    ctx
		    );

            amount_a_64 = (i128::abs_u128(step1_in) as u64);
            amount_b_64 = (i128::abs_u128(step1_out) as u64);
            amount_c_64 = (i128::abs_u128(step2_out) as u64);
        };

        assert!(amount_c_64 >= amount_out_min, ETooLittleReceived);
        pool::swap_coin_a_b_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
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

    public entry fun swap_a_b_c_b<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
		pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
		coins_a: vector<Coin<CoinTypeA>>, 
		amount: u64,
        amount_out_min: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
		ctx: &mut TxContext
    ) {
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a_64, amount_b_64, amount_c_64);

        if (is_exact_in) {
            let (step1_in, step1_out) = pool::swap(
			    pool_a,
                recipient,
			    true,
			    i128::from((amount as u128)),
			    sqrt_price_limit,
                clock,
			    ctx
		    );

            //c for b
            let (step2_out, _step2_in) = pool::swap(
			    pool_b,
                recipient,
			    false,
			    i128::abs(step1_out),
			    MAX_SQRT_PRICE_X64 - 1,
                clock,
			    ctx
		    );
            amount_a_64 = (i128::abs_u128(step1_in) as u64);
            amount_b_64 = (i128::abs_u128(step1_out) as u64);
            amount_c_64 = (i128::abs_u128(step2_out) as u64);
        } else {
            //b for c, exact out
            let (step2_out, step2_in) = pool::swap(
			    pool_b,
                recipient,
			    false,
			    i128::neg_from((amount as u128)),
			    MAX_SQRT_PRICE_X64 - 1,
                clock,
			    ctx
		    );
            
            //a for b, exact out
            let (step1_in, step1_out) = pool::swap(
			    pool_a,
                recipient,
			    true,
			    i128::neg_from(i128::abs_u128(step2_in)),
			    sqrt_price_limit,
                clock,
			    ctx
		    );

            amount_a_64 = (i128::abs_u128(step1_in) as u64);
            amount_b_64 = (i128::abs_u128(step1_out) as u64);
            amount_c_64 = (i128::abs_u128(step2_out) as u64);
        };

        assert!(amount_c_64 >= amount_out_min, ETooLittleReceived);
        pool::swap_coin_a_b_c_b<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
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

    public entry fun swap_b_a_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
		pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
		coins_a: vector<Coin<CoinTypeA>>, 
		amount: u64,
        amount_out_min: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
		ctx: &mut TxContext
    ) {
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a_64, amount_b_64, amount_c_64);

        if (is_exact_in) {
            let (step1_out, step1_in) = pool::swap(
			    pool_a,
                recipient,
			    false,
			    i128::from((amount as u128)),
			    sqrt_price_limit,
                clock,
			    ctx
		    );

            //b for c
            let (_step2_in, step2_out) = pool::swap(
			    pool_b,
                recipient,
			    true,
			    i128::abs(step1_out),
			    MIN_SQRT_PRICE_X64 + 1,
                clock,
			    ctx
		    );

            amount_a_64 = (i128::abs_u128(step1_in) as u64);
            amount_b_64 = (i128::abs_u128(step1_out) as u64);
            amount_c_64 = (i128::abs_u128(step2_out) as u64);
        } else {
            //b for c, exact out
            let (step2_in, step2_out) = pool::swap(
			    pool_b,
                recipient,
			    true,
			    i128::neg_from((amount as u128)),
			    MIN_SQRT_PRICE_X64 + 1,
                clock,
			    ctx
		    );

            //a for b, exact out
            let (step1_out, step1_in) = pool::swap(
			    pool_a,
                recipient,
			    false,
			    i128::neg_from(i128::as_u128(step2_in)),
			    sqrt_price_limit,
                clock,
			    ctx
		    );

            amount_a_64 = (i128::abs_u128(step1_in) as u64);
            amount_b_64 = (i128::abs_u128(step1_out) as u64);
            amount_c_64 = (i128::abs_u128(step2_out) as u64);
        };

        assert!(amount_c_64 >= amount_out_min, ETooLittleReceived);
        pool::swap_coin_b_a_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
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

    public entry fun swap_b_a_c_b<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
		pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
		coins_a: vector<Coin<CoinTypeA>>, 
		amount: u64,
        amount_out_min: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
		ctx: &mut TxContext
    ) {
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a_64, amount_b_64, amount_c_64);

        if (is_exact_in) {
            let (step1_out, step1_in) = pool::swap(
			    pool_a,
                recipient,
			    false,
			    i128::from((amount as u128)),
			    sqrt_price_limit,
                clock,
			    ctx
		    );

            //b for c
            let (step2_out, _step2_in) = pool::swap(
			    pool_b,
                recipient,
			    false,
			    i128::abs(step1_out),
			    MAX_SQRT_PRICE_X64 - 1,
                clock,
			    ctx
		    );

            amount_a_64 = (i128::abs_u128(step1_in) as u64);
            amount_b_64 = (i128::abs_u128(step1_out) as u64);
            amount_c_64 = (i128::abs_u128(step2_out) as u64);
        } else {
            //b for c, exact out
            let (step2_out, step2_in) = pool::swap(
			    pool_b,
                recipient,
			    false,
			    i128::neg_from((amount as u128)),
			    MAX_SQRT_PRICE_X64 - 1,
                clock,
			    ctx
		    );

            //a for b, exact out
            let (step1_out, step1_in) = pool::swap(
			    pool_a,
                recipient,
			    false,
			    i128::neg_from(i128::as_u128(step2_in)),
			    sqrt_price_limit,
                clock,
			    ctx
		    );

            amount_a_64 = (i128::abs_u128(step1_in) as u64);
            amount_b_64 = (i128::abs_u128(step1_out) as u64);
            amount_c_64 = (i128::abs_u128(step2_out) as u64);
        };

        assert!(amount_c_64 >= amount_out_min, ETooLittleReceived);
        pool::swap_coin_b_a_c_b<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
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