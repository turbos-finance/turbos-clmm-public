// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::pool {
	use turbos_clmm::math_tick;
    use sui::transfer;
    use std::string::{Self, String};
	use turbos_clmm::i32::{Self, I32};
	use turbos_clmm::i128::{Self, I128};
	use sui::table::{Self, Table};
    use turbos_clmm::string_tools;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
    use turbos_clmm::tick::{Self, Tick};
    use sui::balance::{Self, Supply, Balance};
    use turbos_clmm::pool_factory;
    use sui::vec_map::{Self, VecMap};
    use sui::coin::{Self, Coin};
	use turbos_clmm::math_liquidity;
	use turbos_clmm::math_sqrt_price;
    use turbos_clmm::full_math_u128;

    const TickNotFound: u64 = 0;
    const EInvildAmount: u64 = 1;
    const EPriceSlippageCheck: u64 = 2;
    const EInvildMintReturnAmount: u64 = 3;
    const EInvildMintAmount: u64 = 4;
    const EInvildTick: u64 = 5;
    const EForPokesZeroPosition: u64 = 6;

	const MAX_U128: u128 = 0xffffffffffffffffffffffffffffffff;
	const MAX_TICK_INDEX: u32 = 443636;
    const Q64: u128 = 0x10000000000000000;

    struct Position has key, store {
        id: UID,
        liquidity: u128,
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        tokens_owed_a: u64,
        tokens_owed_b: u64,
    }

    struct Pool<phantom CoinTypeA, phantom CoinTypeB> has key, store {
        id: UID,
        coin_a: Balance<CoinTypeA>,
        coin_b: Balance<CoinTypeB>,
        protocol_fees_coin_a: Balance<CoinTypeA>,
        protocol_fees_coin_b: Balance<CoinTypeB>,
        sqrt_price: u128,
        tick_current_index: I32,
        tick_spacing: u32,
        max_liquidity_per_tick: u128,
        fee: u32,
        fee_protocol: u32,
        unlocked: bool,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        liquidity: u128,
        user_position: VecMap<address, vector<ID>>,
    }

    fun init(ctx: &mut TxContext) {
        //some init
    }

    public fun deploy_pool<CoinTypeA, CoinTypeB>(
        fee: u32,
        tick_spacing: u32,
        sqrt_price: u128,
        ctx: &mut TxContext
    ) :Pool<CoinTypeA, CoinTypeB> {
        let tick_current_index = math_tick::tick_index_from_sqrt_price(sqrt_price);
        let max_liquidity_per_tick = tick::max_liquidity_per_tick(tick_spacing);

        Pool {
            id: object::new(ctx), 
            coin_a: balance::zero<CoinTypeA>(),
            coin_b: balance::zero<CoinTypeB>(),
            protocol_fees_coin_a: balance::zero<CoinTypeA>(),
            protocol_fees_coin_b: balance::zero<CoinTypeB>(),
            sqrt_price: sqrt_price,
            tick_current_index: tick_current_index,
            tick_spacing: tick_spacing,
            max_liquidity_per_tick: max_liquidity_per_tick,
            fee: fee,
            fee_protocol: 0,
            unlocked: true,
            fee_growth_global_a: 0,
            fee_growth_global_b: 0,
            liquidity: 0,
            user_position: vec_map::empty()
        }
    }

    public fun mint<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: u128,
        ctx: &mut TxContext,
    ): (u64, u64) {
        assert!(liquidity_delta > 0, EInvildAmount);

        let (amount_a, amount_b) = modify_position(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            i128::from(liquidity_delta),
            ctx
        );

        assert!(!i128::is_neg(amount_a) && !i128::is_neg(amount_b), EInvildMintReturnAmount);
        let (amount_a_u64, amount_b_u64) = ((i128::abs_u128(amount_a) as u64), (i128::abs_u128(amount_b) as u64));

        let balance_a_before = balance::value(&pool.coin_a);
        let balance_b_before = balance::value(&pool.coin_b);

        split_and_transfer(
            pool, 
            coin_a, 
		    amount_a_u64,
		    coin_b, 
		    amount_b_u64,
            ctx
        );

        let balance_a_current = balance::value(&pool.coin_a);
        let balance_b_current = balance::value(&pool.coin_b);

        assert!(balance_a_before + amount_a_u64 <= balance_a_current, EInvildMintAmount);
        assert!(balance_b_current + amount_b_u64 <= balance_b_current, EInvildMintAmount);

        (amount_a_u64, amount_b_u64)
    }

    public fun burn<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: u128,
        ctx: &mut TxContext
    ): (u64, u64) {
        let (amount_a, amount_b) = modify_position(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            i128::neg_from(liquidity_delta),
            ctx
        );

        let (amount_a_u64, amount_b_u64) = ((i128::abs_u128(amount_a) as u64), (i128::abs_u128(amount_b) as u64));

        if (amount_a_u64 > 0 || amount_b_u64 > 0) {
            let position = get_position_mut(pool, owner, tick_lower_index, tick_upper_index);
            position.tokens_owed_a = position.tokens_owed_a + amount_a_u64;
            position.tokens_owed_b = position.tokens_owed_b + amount_b_u64;
        };

        (amount_a_u64, amount_b_u64)
    }

    public fun collect<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a_requested: u64,
        amount_b_requested: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        let owner = tx_context::sender(ctx);
        let position = get_position_mut(pool, owner, tick_lower_index, tick_upper_index);

        let amount_a = if (amount_a_requested > position.tokens_owed_a) position.tokens_owed_a else amount_a_requested;
        let amount_b = if (amount_b_requested > position.tokens_owed_b) position.tokens_owed_b else amount_b_requested;

        if (amount_a > 0) {
            position.tokens_owed_a = position.tokens_owed_a - amount_a;
        };
        if (amount_b > 0) {
            position.tokens_owed_b = position.tokens_owed_b - amount_b;
        };
        transfer_out(
            pool,
            amount_a,
            amount_b,
            recipient,
            ctx
        );

        (amount_a, amount_b)
    }

    /// @return amount_a the amount of token0 owed to the pool, negative if the pool should pay the recipient
    /// @return amount_b the amount of token1 owed to the pool, negative if the pool should pay the recipient
    public fun  modify_position<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: I128,
        ctx: &mut TxContext,
    ): (I128, I128){
        check_ticks(tick_lower_index, tick_upper_index);

        update_position(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            liquidity_delta,
            ctx,
        );
        let amount_a = i128::zero();
        let amount_b = i128::zero();

        if (!i128::eq(liquidity_delta, i128::zero())) {
            if (i32::lt(pool.tick_current_index, tick_lower_index)) {
                // current tick is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
                amount_a = math_sqrt_price::get_amount_a_delta(
                    math_tick::sqrt_price_from_tick_index(tick_lower_index),
                    math_tick::sqrt_price_from_tick_index(tick_lower_index),
                    liquidity_delta
                );
            } else if (i32::lt(pool.tick_current_index, tick_upper_index)) {
                amount_a = math_sqrt_price::get_amount_a_delta(
                    pool.sqrt_price,
                    math_tick::sqrt_price_from_tick_index(tick_upper_index),
                    liquidity_delta
                );
                amount_b = math_sqrt_price::get_amount_b_delta(
                    math_tick::sqrt_price_from_tick_index(tick_lower_index),
                    pool.sqrt_price,
                    liquidity_delta
                );

                pool.liquidity = math_liquidity::add_delta(pool.liquidity, liquidity_delta);
            } else {
                // current tick is above the passed range; liquidity can only become in range by crossing from right to
                // left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
                amount_b = math_sqrt_price::get_amount_b_delta(
                    math_tick::sqrt_price_from_tick_index(tick_lower_index),
                    math_tick::sqrt_price_from_tick_index(tick_lower_index),
                    liquidity_delta
                );
            };
        };

        (amount_a, amount_b)
    }

    public fun update_position<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: I128,
        ctx: &mut TxContext,
    ) {
        let position = get_position(pool, owner, tick_lower_index, tick_upper_index);
        let tick_current_index = pool.tick_current_index;

        // if we need to update the ticks, do it
        let flipped_lower = false;
        let flipped_upper = false;
        if (!i128::eq(liquidity_delta, i128::zero())) {
            flipped_lower = update_tick(
                pool,
                tick_lower_index,
                tick_current_index,
                liquidity_delta,
                false,
                ctx,
            );
            flipped_upper = update_tick(
                pool,
                tick_upper_index,
                tick_current_index,
                liquidity_delta,
                true,
                ctx,
            );

            if (flipped_lower) {
                flip_tick(pool, tick_lower_index, ctx);
            };
            if (flipped_upper) {
                flip_tick(pool, tick_upper_index, ctx);
            };
        };

        let (fee_growth_inside_a, fee_growth_inside_b) = get_fee_growth_inside(
            pool,
            tick_lower_index,
            tick_upper_index,
            tick_current_index,
            ctx
        );

        update_position_metadata(
            pool, 
            get_position_key(owner, tick_lower_index, tick_upper_index),
            liquidity_delta, 
            fee_growth_inside_a, 
            fee_growth_inside_b, 
            ctx
        );

        // clear any tick data that is no longer needed
        if (i128::is_neg(liquidity_delta)) {
            if (flipped_lower) {
                clear_tick(pool, tick_lower_index, ctx);
            };
            if (flipped_upper) {
                clear_tick(pool, tick_upper_index, ctx);
            };
        };
    }

    public fun check_ticks(
        tick_lower_index: I32,
        tick_upper_index: I32
    ) {
        assert!(i32::lt(tick_lower_index, tick_lower_index), EInvildTick);
        assert!(i32::gte(tick_lower_index, i32::neg_from(MAX_TICK_INDEX)), EInvildTick);
        assert!(i32::lte(tick_upper_index, i32::from(MAX_TICK_INDEX)), EInvildTick);
    }

    public fun update_tick<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        tick_index: I32,
        tick_current_index: I32,
        liquidity_delta: I128,
        is_upper: bool,
        ctx: &mut TxContext,
    ): bool {
        false
    }

    public fun clear_tick<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        tick_index: I32,
        ctx: &mut TxContext,
    ): bool {
        false
    }

    public fun flip_tick<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        tick_index: I32,
        ctx: &mut TxContext,
    ) {

    }

    public fun get_fee_growth_inside<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        tick_lower_index: I32,
        tick_upper_index: I32,
        tick_current_index: I32,
        ctx: &mut TxContext,
    ): (u128, u128) {
        (1,1)
    }

    public fun update_position_metadata<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position_key: String,
        liquidity_delta: I128,
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        ctx: &mut TxContext,
    ) {
        let position = get_position_mut_by_key(pool, position_key);

        let liquidity_next;
        if (i128::eq(liquidity_delta, i128::zero())) {
            assert!(position.liquidity > 0, EForPokesZeroPosition); // disallow pokes for 0 liquidity positions
            liquidity_next = position.liquidity;
        } else {
            liquidity_next = math_liquidity::add_delta(position.liquidity, liquidity_delta);
        };

        // calculate accumulated fees
        let tokens_owed_a = (full_math_u128::mul_div_floor(fee_growth_inside_a - position.fee_growth_inside_a, position.liquidity, Q64) as u64);
        let tokens_owed_b = (full_math_u128::mul_div_floor(fee_growth_inside_b - position.fee_growth_inside_b, position.liquidity, Q64) as u64);

        // update the position
        if (!i128::eq(liquidity_delta, i128::zero())) position.liquidity = liquidity_next;
        position.fee_growth_inside_a = fee_growth_inside_a;
        position.fee_growth_inside_b = fee_growth_inside_b;
        if (tokens_owed_a > 0 || tokens_owed_b > 0) {
            // overflow is acceptable, have to withdraw before you hit type(uint128).max fees
            position.tokens_owed_a = position.tokens_owed_a + tokens_owed_a;
            position.tokens_owed_b = position.tokens_owed_b + tokens_owed_b;
        }
    }

    public fun get_position<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): &Position {
        get_position_by_key(pool, get_position_key(owner, tick_lower_index, tick_upper_index))
    }

    public fun get_position_mut<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): &mut Position {
        get_position_mut_by_key(pool, get_position_key(owner, tick_lower_index, tick_upper_index))
    }

    public fun get_position_by_key<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        key: String
    ): &Position {
        dof::borrow<String, Position>(&pool.id, key)
    }

    public fun get_position_mut_by_key<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        key: String
    ): &mut Position {
        dof::borrow_mut<String, Position>(&mut pool.id, key)
    }

    public fun get_position_key(
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): String {
        string_tools::get_position_key(
            owner, 
            i32::as_u32(tick_lower_index),
            i32::is_neg(tick_lower_index),
            i32::as_u32(tick_upper_index),
            i32::is_neg(tick_upper_index)
        )
    }

    public fun get_pool_fee<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
    ): u32 {
        pool.fee
    }

    public fun get_pool_sqrt_price<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
    ): u128 {
        pool.sqrt_price
    }

    public fun get_position_fee_growth_inside_a<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        key: String
    ): u128 {
        let position = get_position_by_key(pool, key);
        position.fee_growth_inside_a
    }

    public fun get_position_fee_growth_inside_b<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        key: String
    ): u128 {
        let position = get_position_by_key(pool, key);
        position.fee_growth_inside_b
    }

    public fun transfer_in<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        coin_a: Coin<CoinTypeA>, 
        coin_b: Coin<CoinTypeB>, 
    ) {
        balance::join(&mut pool.coin_a, coin::into_balance(coin_a));
        balance::join(&mut pool.coin_b, coin::into_balance(coin_b));
    }

    public fun transfer_out<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        amount_a: u64, 
        amount_b: u64, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        if (amount_a > 0) {
            let amount_out_balance = balance::split(&mut pool.coin_a, amount_a);
            let amount_out_coin = coin::from_balance(amount_out_balance, ctx);
            transfer::transfer(amount_out_coin, recipient);
        };
        if (amount_b > 0) {
            let amount_out_balance = balance::split(&mut pool.coin_b, amount_b);
            let amount_out_coin = coin::from_balance(amount_out_balance, ctx);
            transfer::transfer(amount_out_coin, recipient);
        };
    }

    fun split_and_transfer<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>, 
        coin_a: Coin<CoinTypeA>, 
		amount_a: u64,
		coin_b: Coin<CoinTypeB>, 
		amount_b: u64,
        ctx: &mut TxContext
    ) {
        let left_a = coin::split(&mut coin_a, amount_a, ctx);

        let left_b = coin::split(&mut coin_b, amount_a, ctx);

		transfer_in(pool, left_a, left_b);

		if (coin::value(&coin_a) == 0) {
            coin::destroy_zero(coin_a);
        } else {
            transfer::transfer(
                coin_a,
                tx_context::sender(ctx)
            );
        };

		if (coin::value(&coin_b) == 0) {
            coin::destroy_zero(coin_b);
        } else {
            transfer::transfer(
                coin_b,
                tx_context::sender(ctx)
            );
        };
    }

    // public fun mint(
    //     owner: address,
    //     tick_lower_index: I32,
    //     tick_upper_index: I32,
    //     amount: u128,
    // ){
       
    // }

    // public fun burn(
    //     owner: address,
    //     tick_lower_index: I32,
    //     tick_upper_index: I32,
    //     amount: u128,
    // ){
    // }

    // public fun swap(
    //     owner: address,
    //     a_for_b: bool,
    //     amount_specified: u128,
    //     sqrt_price_limit: u128,
    // ){
        
    // }

    // public fun collect(
    //     owner: address,
    //     tick_lower_index: I32,
    //     tick_upper_index: I32,
    //     amount_a_requested: u128,
    //     amount_b_requested: u128,
    // ){
        
    // }

    // public fun update_position(
    //     owner: address,
    //     tick_lower_index: I32,
    //     tick_upper_index: I32,
    //     tick_current_index: I32,
    //     liquidity_delta: I128,
    // ) {
    // }
    
}