// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::swap_router {
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};

    const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;

    const ECoinsVectorMustBeEmpty: u64 = 1;
    const ETransactionToOld: u64 = 2;
    const ETooLittleReceived: u64 = 3; 
    const EAmountOutBelowMinimum: u64 = 4; 
    const EAmountInAboveMaximum: u64 = 5; 
    const ETwoStepSwapLackOfLiquidity: u64 = 6; 
    
    public entry fun swap_a_b<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_b_out, coin_a_left) = swap_a_b_with_return_(
            pool,
            coins_a,
            amount,
            amount_threshold,
            sqrt_price_limit,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_b_out, recipient);

        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        };
    }

    public fun swap_a_b_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeB>, Coin<CoinTypeA>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a, amount_b) = pool::swap(
            pool,
            recipient,
            true,
            (amount as u128),
            is_exact_in,
            sqrt_price_limit,
            clock,
            ctx
        );
        let amount_a_64 = (amount_a as u64);
        let amount_b_64 = (amount_b as u64);
        check_amount_threshold(is_exact_in, true, amount_a_64, amount_b_64, amount_threshold);

        pool::swap_coin_a_b_with_return_(
            pool,
            pool::merge_coin(coins_a),
            amount_a_64,
            amount_b_64,
            ctx
        )
    }

    public entry fun swap_b_a<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coins_b: vector<Coin<CoinTypeB>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_a_out, coin_b_left) = swap_b_a_with_return_(
            pool,
            coins_b,
            amount,
            amount_threshold,
            sqrt_price_limit,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_a_out, recipient);

        if (coin::value(&coin_b_left) == 0) {
            coin::destroy_zero(coin_b_left);
        } else {
            transfer::public_transfer(
                coin_b_left,
                tx_context::sender(ctx)
            );
        };
    }

    public fun swap_b_a_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coins_b: vector<Coin<CoinTypeB>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a, amount_b) = pool::swap(
            pool,
            recipient,
            false,
            (amount as u128),
            is_exact_in,
            sqrt_price_limit,
            clock,
            ctx
        );
        let amount_a_64 = (amount_a as u64);
        let amount_b_64 = (amount_b as u64);
        check_amount_threshold(is_exact_in, false, amount_a_64, amount_b_64, amount_threshold);

        pool::swap_coin_b_a_with_return_(
            pool,
            pool::merge_coin(coins_b),
            amount_b_64,
            amount_a_64,
            ctx
        )
    }

    fun check_amount_threshold(
        is_exact_in: bool,
        a_to_b: bool,
        amount_a: u64, 
        amount_b: u64, 
        amount_threshold: u64
    ) {
        if (is_exact_in) {
            if ((a_to_b && amount_threshold > amount_b)
                || (!a_to_b && amount_threshold > amount_a))
            {
                abort EAmountOutBelowMinimum
            }
        } else {
            if ((a_to_b && amount_threshold < amount_a)
                || (!a_to_b && amount_threshold < amount_b))
            {
                abort EAmountInAboveMaximum
            }
        }
    }

    // such as: pool a: BTC/USDC, pool b: USDC/ETH
    // if swap BTC to ETH,route is BTC -> USDC -> ETH,fee paid in BTC and USDC 
    // step one: swap BTC to USDC (a to b), step two: swap USDC to ETH (a to b)
    public entry fun swap_a_b_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_c_out, coin_a_left) = swap_a_b_b_c_with_return_(
            pool_a,
            pool_b,
            coins_a,
            amount,
            amount_threshold,
            sqrt_price_limit_one,
            sqrt_price_limit_two,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_c_out, recipient);

        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        };
    }

    public fun swap_a_b_b_c_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a_64, amount_b_64, amount_c_64);

        let a_to_b_step_one = true;
        let a_to_b_step_two = true;
        if (is_exact_in) {
            let (step1_in, step1_out) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );

            let (step2_in, step2_out) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                step1_out,
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold <= amount_c_64, EAmountOutBelowMinimum);
        } else {
            let (step2_in, step2_out) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );

            let (step1_in, step1_out) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                step2_in,
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold >= amount_a_64, EAmountInAboveMaximum);
        };

        pool::swap_coin_a_b_b_c_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
            pool_a,
            pool_b,
            pool::merge_coin(coins_a),
            amount_a_64,
            amount_b_64,
            amount_c_64,
            ctx
        )
    }

    // such as: pool a: BTC/USDC, pool b: ETH/USDC
    // if swap BTC to ETH, route is BTC -> USDC -> ETH,fee paid in BTC and USDC 
    // step one: swap BTC to USDC (a to b), step two: swap USDC to ETH (b to a)
    public entry fun swap_a_b_c_b<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_c_out, coin_a_left) = swap_a_b_c_b_with_return_(
            pool_a,
            pool_b,
            coins_a,
            amount,
            amount_threshold,
            sqrt_price_limit_one,
            sqrt_price_limit_two,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_c_out, recipient);

        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        };
    }

     public fun swap_a_b_c_b_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a_64, amount_b_64, amount_c_64);

        let a_to_b_step_one = true;
        let a_to_b_step_two = false;
        if (is_exact_in) {
            let (step1_in, step1_out) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );

            let (step2_out, step2_in) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                step1_out,
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold <= amount_c_64, EAmountOutBelowMinimum);
        } else {
            //b for c, exact out
            let (step2_out, step2_in) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );
            
            //a for b, exact out
            let (step1_in, step1_out) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                step2_in,
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold >= amount_a_64, EAmountInAboveMaximum);
        };

        pool::swap_coin_a_b_c_b_with_return<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
            pool_a,
            pool_b,
            pool::merge_coin(coins_a),
            amount_a_64,
            amount_b_64,
            amount_c_64,
            ctx,
        )
    }

    // such as: pool a: USDC/BTC, pool b: USDC/ETH
    // if swap BTC to ETH, route is BTC -> USDC -> ETH, fee paid in BTC and USDC 
    // step one: swap BTC to USDC (b to a), step two: swap USDC to ETH (a to b)
    public entry fun swap_b_a_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_c_out, coin_a_left) = swap_b_a_b_c_with_return_(
            pool_a,
            pool_b,
            coins_a,
            amount,
            amount_threshold,
            sqrt_price_limit_one,
            sqrt_price_limit_two,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_c_out, recipient);

        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        }
    }

    public fun swap_b_a_b_c_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a_64, amount_b_64, amount_c_64);

        let a_to_b_step_one = false;
        let a_to_b_step_two = true;
        if (is_exact_in) {
            let (step1_out, step1_in) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );

            let (step2_in, step2_out) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                step1_out,
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold <= amount_c_64, EAmountOutBelowMinimum);
        } else {
            let (step2_in, step2_out) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );

            let (step1_out, step1_in) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                step2_in,
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold >= amount_a_64, EAmountInAboveMaximum);

        };

        pool::swap_coin_b_a_b_c_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
            pool_a,
            pool_b,
            pool::merge_coin(coins_a),
            amount_a_64,
            amount_b_64,
            amount_c_64,
            ctx
        )
    }

    // such as: pool a: USDC/BTC, pool b: ETH/USDC
    // if swap BTC to ETH, route is BTC -> USDC -> ETH, fee paid in BTC and USDC 
    // step one: swap BTC to USDC (b to a), step two: swap USDC to ETH (b to a)
    public entry fun swap_b_a_c_b<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_c_out, coin_a_left) = swap_b_a_c_b_with_return_(
            pool_a,
            pool_b,
            coins_a,
            amount,
            amount_threshold,
            sqrt_price_limit_one,
            sqrt_price_limit_two,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_c_out, recipient);

        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        }
    }

     public fun swap_b_a_c_b_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let (amount_a_64, amount_b_64, amount_c_64);

        let a_to_b_step_one = false;
        let a_to_b_step_two = false;
        if (is_exact_in) {
            let (step1_out, step1_in) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );

            //b for c
            let (step2_out, step2_in) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                step1_out,
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold <= amount_c_64, EAmountOutBelowMinimum);
        } else {
            let (step2_out, step2_in) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_one,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );

            let (step1_out, step1_in) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_two,
                step2_in,
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold >= amount_a_64, EAmountInAboveMaximum);
        };

        pool::swap_coin_b_a_c_b_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
            pool_a,
            pool_b,
            pool::merge_coin(coins_a),
            amount_a_64,
            amount_b_64,
            amount_c_64,
            ctx
        )
    }
}