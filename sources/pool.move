// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::pool {
	use std::vector;
	use sui::pay;
    use sui::transfer;
    use std::string::{String};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
	use sui::dynamic_field as df;
    use sui::balance::{Self, Balance};
    use sui::vec_map::{Self, VecMap};
    use sui::coin::{Self, Coin};
	use turbos_clmm::math_tick;
	use turbos_clmm::math_swap;
    use turbos_clmm::string_tools;
	use turbos_clmm::i32::{Self, I32};
	use turbos_clmm::i128::{Self, I128};
	use turbos_clmm::math_liquidity;
	use turbos_clmm::math_sqrt_price;
    use turbos_clmm::full_math_u128;
	use turbos_clmm::math_bit;

    friend turbos_clmm::position_manager;
    friend turbos_clmm::pool_factory;
    friend turbos_clmm::swap_router;

    const TickNotFound: u64 = 0;
    const EInvildAmount: u64 = 1;
    const EPriceSlippageCheck: u64 = 2;
    const EInvildMintReturnAmount: u64 = 3;
    const EInvildMintAmount: u64 = 4;
    const EInvildTick: u64 = 5;
    const EForPokesZeroPosition: u64 = 6;
	const ESwapAmountSpecifiedZero: u64 = 7;
	const EPoolLocked: u64 = 8;
	const ESwapLessThanMinSqrtPrice: u64 = 9;
	const ESwapGatherThanMaxSqrtPrice: u64 = 10;
	const EPoolOverflow: u64 = 11;
	const EInvildTickIndex: u64 = 12;

	const MAX_U128: u128 = 0xffffffffffffffffffffffffffffffff;
	const MAX_TICK_INDEX: u32 = 443636;
    const Q64: u128 = 0x10000000000000000;
	const MIN_SQRT_PRICE: u128 = 4295048016;
	const MAX_SQRT_PRICE: u128 = 79226673515401279992447579055;

	struct Tick has key, store {
		id: UID,
        liquidity_gross: u128,
        liquidity_net: I128,
        fee_growth_outside_a: u128,
		fee_growth_outside_b: u128,
        initialized: bool,
    }

    struct Position has key, store {
        id: UID,
		// the amount of liquidity owned by this position
        liquidity: u128,
		// fee growth per unit of liquidity as of the last update to liquidity or fees owed
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
		// the fees owed to the position owner in token0/token1
        tokens_owed_a: u64,
        tokens_owed_b: u64,
    }

    struct Pool<phantom CoinTypeA, phantom CoinTypeB, phantom FeeType> has key, store {
        id: UID,
        coin_a: Balance<CoinTypeA>,
        coin_b: Balance<CoinTypeB>,
        protocol_fees_a: u64,
        protocol_fees_b: u64,
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
		tick_map: VecMap<I32, u256>,
    }

    fun init(_ctx: &mut TxContext) {
        //some init
    }

    public(friend) fun deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
        fee: u32,
        tick_spacing: u32,
        sqrt_price: u128,
        fee_protocol: u32,
        ctx: &mut TxContext
    ) :Pool<CoinTypeA, CoinTypeB, FeeType> {
        let tick_current_index = math_tick::tick_index_from_sqrt_price(sqrt_price);
        let max_liquidity_per_tick = math_tick::max_liquidity_per_tick(tick_spacing);

        Pool {
            id: object::new(ctx), 
            coin_a: balance::zero<CoinTypeA>(),
            coin_b: balance::zero<CoinTypeB>(),
            protocol_fees_a: 0,
            protocol_fees_b: 0,
            sqrt_price: sqrt_price,
            tick_current_index: tick_current_index,
            tick_spacing: tick_spacing,
            max_liquidity_per_tick: max_liquidity_per_tick,
            fee: fee,
            fee_protocol: fee_protocol,
            unlocked: true,
            fee_growth_global_a: 0,
            fee_growth_global_b: 0,
            liquidity: 0,
            user_position: vec_map::empty(),
			tick_map: vec_map::empty()
        }
    }

    public(friend) fun mint<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: u128,
        ctx: &mut TxContext,
    ): (u64, u64) {
        assert!(liquidity_delta > 0, EInvildAmount);

		try_init_position(
			pool,
			owner,
            tick_lower_index,
            tick_upper_index,
			ctx
		);

        let (amount_a, amount_b) = modify_position(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            i128::from(liquidity_delta),
            ctx
        );

        assert!(!i128::is_neg(amount_a) && !i128::is_neg(amount_b), EInvildMintReturnAmount);

        ((i128::abs_u128(amount_a) as u64), (i128::abs_u128(amount_b) as u64))
    }

    public(friend) fun burn<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
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

	public(friend) fun swap<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        a_for_b: bool,
        amount_specified: I128,
        sqrt_price_limit: u128,
        ctx: &mut TxContext
    ): (I128, I128) {
        assert!(!i128::eq(amount_specified, i128::zero()), ESwapAmountSpecifiedZero);
        assert!(pool.unlocked, EPoolLocked);
        if (a_for_b) {
            assert!(sqrt_price_limit < pool.sqrt_price && sqrt_price_limit > MIN_SQRT_PRICE, ESwapLessThanMinSqrtPrice);
        } else {
            assert!(sqrt_price_limit > pool.sqrt_price && sqrt_price_limit < MAX_SQRT_PRICE, ESwapGatherThanMaxSqrtPrice);
        };
		let exact_input = i128::gt(amount_specified, i128::zero());

		//cache
        let liquidity_start = pool.liquidity;

		//state
		let amount_specified_remaining = amount_specified;
		let amount_calculated = i128::zero();
		let sqrt_price = pool.sqrt_price;
		let tick_current_index = pool.tick_current_index;
		let fee_growth_global = if (a_for_b) pool.fee_growth_global_a else pool.fee_growth_global_b;
		let protocol_fee = 0;
		let liquidity = pool.liquidity;

		while (!i128::eq(amount_specified_remaining, i128::zero()) && sqrt_price !=sqrt_price_limit) {
			let step_sqrt_price_start = sqrt_price;
			let (step_tick_next_index, step_initialized) = next_initialized_tick_within_one_word(
				pool,
				tick_current_index,
				a_for_b
			);

			if (i32::lt(step_tick_next_index, i32::neg_from(MAX_TICK_INDEX))) {
				step_tick_next_index = i32::neg_from(MAX_TICK_INDEX);
			} else if (i32::gt(step_tick_next_index, i32::from(MAX_TICK_INDEX))) {
				step_tick_next_index = i32::from(MAX_TICK_INDEX);
			};

			let step_sqrt_price_next = math_tick::sqrt_price_from_tick_index(step_tick_next_index);
			// compute values to swap to the target tick, price limit, or point where input/output amount is exhausted
			let step_amount_in;
			let step_amount_out;
			let step_fee_amount;
			let limit = if (a_for_b) step_sqrt_price_next < sqrt_price_limit else step_sqrt_price_next > sqrt_price_limit;
            let target = if (limit) sqrt_price_limit else step_sqrt_price_next;
            (sqrt_price, step_amount_in, step_amount_out, step_fee_amount) = math_swap::compute_swap(
                sqrt_price,
                target,
                liquidity,
                amount_specified_remaining,
                pool.fee
            );

			if (exact_input) {
				amount_specified_remaining = i128::sub(amount_specified_remaining, i128::from(step_amount_in + step_fee_amount));
				amount_calculated = i128::sub(amount_calculated, i128::from(step_amount_out));
			} else {
				amount_specified_remaining = i128::add(amount_specified_remaining, i128::from(step_amount_out));
				amount_calculated = i128::add(amount_calculated, i128::from(step_amount_in + step_fee_amount));
			};

			if (pool.fee_protocol > 0) {
				let delta = step_fee_amount * (pool.fee_protocol as u128) / 10000;
                step_fee_amount = step_fee_amount - delta;
                protocol_fee = protocol_fee + delta;
			};

			if (liquidity > 0) {
				fee_growth_global = fee_growth_global + full_math_u128::mul_div_floor(step_fee_amount, Q64, liquidity);
			};

			if (sqrt_price == step_sqrt_price_next) {
				if (step_initialized) {
					let (fee_growth_global_a, fee_growth_global_b) = (pool.fee_growth_global_a, pool.fee_growth_global_b);
					let liquidity_net = cross_tick(
						pool,
                        step_tick_next_index,
                        if(a_for_b) fee_growth_global else fee_growth_global_a,
                        if(a_for_b) fee_growth_global_b else fee_growth_global,
						ctx
                    );
                    // if we're moving leftward, we interpret liquidity_net as the opposite sign
                    // safe because liquidity_net cannot be type(int128).min
                    if (a_for_b) {
						liquidity_net = i128::neg(liquidity_net);
					};

                    liquidity = math_liquidity::add_delta(liquidity, liquidity_net);
				};
				tick_current_index = if (a_for_b) i32::sub(step_tick_next_index, i32::from(1)) else step_tick_next_index;
			} else if (sqrt_price != step_sqrt_price_start) {
				tick_current_index = math_tick::tick_index_from_sqrt_price(sqrt_price);
			};
		};
        
        if (!i32::eq(tick_current_index, pool.tick_current_index)) {
            pool.sqrt_price = sqrt_price;
            pool.tick_current_index = tick_current_index;
        } else {
		    pool.sqrt_price = sqrt_price;
        };

		if (liquidity_start != liquidity) pool.liquidity = liquidity;

		if (a_for_b) {
			pool.fee_growth_global_a = fee_growth_global;
			if (protocol_fee > 0) {
				pool.protocol_fees_a = pool.protocol_fees_a + (protocol_fee as u64);
			};
		} else {
			pool.fee_growth_global_b = fee_growth_global;
			if (protocol_fee > 0) {
				pool.protocol_fees_b = pool.protocol_fees_b + (protocol_fee as u64);
			};
		};

		let (amount_a, amount_b) = if (a_for_b == exact_input) {
            (i128::sub(amount_specified, amount_specified_remaining), amount_calculated)
		} else {
			(amount_calculated, i128::sub(amount_specified, amount_specified_remaining))
		};
       
		(amount_a, amount_b)
    }


    public(friend) fun collect<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
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

        (amount_a, amount_b)
    }

	fun next_initialized_tick_within_one_word<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		tick_current_index: I32,
		lte: bool
	): (I32, bool) {
		let compressed = i32::div(tick_current_index, i32::from(pool.tick_spacing));

		// round towards negative infinity
		if (
			i32::lt(tick_current_index, i32::zero()) && 
			!i32::eq(i32::mod_euclidean(tick_current_index, i32::from(pool.tick_spacing)), i32::zero())
		) {
 			compressed = i32::sub(compressed, i32::from(1));
		};
		let next: I32;
		let initialized: bool;
		if (lte) {
            let (word_pos, bit_pos) = position_tick(compressed);
			try_init_tick_word(pool, word_pos);
			let word = get_tick_word(pool, word_pos);
            // all the 1s at or to the right of the current bit_pos
            let mask: u256 = (1 << bit_pos) - 1 + (1 << bit_pos);
            let masked: u256 = word & mask;

            // if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = if (initialized) {
				i32::mul(
                	i32::sub(compressed, i32::from((bit_pos - math_bit::most_significant_bit(masked) as u32))), 
					i32::from(pool.tick_spacing)
				)
			} else { 
				i32::mul(
					i32::sub(compressed, i32::from((bit_pos as u32))),
					i32::from(pool.tick_spacing)
				)
			};
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            let (word_pos, bit_pos) = position_tick(i32::add(compressed, i32::from(1)));
			try_init_tick_word(pool, word_pos);
			let word = get_tick_word(pool, word_pos);
            // all the 1s at or to the left of the bit_pos
			// like ~((1 << bit_pos) - 1)
            let mask: u256 = ((1 << bit_pos) - 1) ^ 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
            let masked = word & mask;

            // if there are no initialized ticks to the left of the current tick, return leftmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
			next = if (initialized) {
				i32::mul(
                	i32::add(
						i32::add(compressed, i32::from(1)),
						i32::sub(i32::from((math_bit::least_significant_bit(masked) as u32)), i32::from((bit_pos as u32)))
					), 
					i32::from(pool.tick_spacing)
				)
			} else { 
				i32::mul(
					i32::add(
						i32::add(compressed, i32::from(1)),
						i32::from(((255 - bit_pos) as u32))
					),
					i32::from(pool.tick_spacing)
				)
			};
        };

		(next, initialized)
	}

	public fun position_tick(tick: I32): (I32, u8) {
        //let word_pos = i32::div(tick, i32::from(256));
		let word_pos = i32::shr(tick, 8);
        let bit_pos = (i32::abs_u32(i32::mod_euclidean(tick, i32::from(256))) as u8);
		//let bit_pos = ((i32::abs_u32(tick) % 256) as u8);

		(word_pos, bit_pos)
    }

    fun try_init_tick_word<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		word_pos: I32
	) {
		if (!vec_map::contains(&pool.tick_map, &word_pos)) {
			vec_map::insert(&mut pool.tick_map, word_pos, 0u256);
		};
    }

	fun get_tick_word<CoinTypeA, CoinTypeB, FeeType>(
		pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
		word_pos: I32
	): u256 {
		*vec_map::get(& pool.tick_map, &word_pos)
    }

	fun get_tick_word_mut<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		word_pos: I32
	): &mut u256 {
		vec_map::get_mut(&mut pool.tick_map, &word_pos)
    }

    /// @return amount_a the amount of token0 owed to the pool, negative if the pool should pay the recipient
    /// @return amount_b the amount of token1 owed to the pool, negative if the pool should pay the recipient
    fun modify_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
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
                    math_tick::sqrt_price_from_tick_index(tick_upper_index),
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
                    math_tick::sqrt_price_from_tick_index(tick_upper_index),
                    liquidity_delta
                );
            };
        };

        (amount_a, amount_b)
    }

	fun try_init_position<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
		ctx: &mut TxContext
	) {
		let key = get_position_key(owner, tick_lower_index, tick_upper_index);
		if (!dof::exists_(&pool.id, key)) {
			dof::add(&mut pool.id, key, Position {
				id: object::new(ctx),
        		liquidity: 0,
        		fee_growth_inside_a: 0,
        		fee_growth_inside_b: 0,
        		tokens_owed_a: 0,
        		tokens_owed_b: 0,
			});
		};
    }

    fun update_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: I128,
        ctx: &mut TxContext,
    ) {
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

    fun check_ticks(
        tick_lower_index: I32,
        tick_upper_index: I32
    ) {
        assert!(i32::lt(tick_lower_index, tick_upper_index), EInvildTick);
        assert!(i32::gte(tick_lower_index, i32::neg_from(MAX_TICK_INDEX)), EInvildTick);
        assert!(i32::lte(tick_upper_index, i32::from(MAX_TICK_INDEX)), EInvildTick);
    }

    fun update_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
        tick_current_index: I32,
        liquidity_delta: I128,
        is_upper: bool,
        ctx: &mut TxContext,
    ): bool {
        let tick;
		let fee_growth_global_a = pool.fee_growth_global_a;
		let fee_growth_global_b = pool.fee_growth_global_b;
		let max_liquidity_per_tick = pool.max_liquidity_per_tick;
		if (!df::exists_(&pool.id, tick_index)) {
			tick = init_tick(pool, tick_index, ctx);
		} else {
			tick = df::borrow_mut<I32, Tick>(&mut pool.id, tick_index);
		};

        let liquidity_gross_before = tick.liquidity_gross;
        let liquidity_gross_after = math_liquidity::add_delta(liquidity_gross_before, liquidity_delta);

        assert!(liquidity_gross_after <= max_liquidity_per_tick, EPoolOverflow);

        let flipped = (liquidity_gross_after == 0) != (liquidity_gross_before == 0);

        if (liquidity_gross_before == 0) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (i32::lte(tick_index, tick_current_index)) {
                tick.fee_growth_outside_a = fee_growth_global_a;
                tick.fee_growth_outside_b = fee_growth_global_b;
            };
            tick.initialized = true;
        };

        tick.liquidity_gross = liquidity_gross_after;

        // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
        tick.liquidity_net = if (is_upper) {
			i128::sub(tick.liquidity_net, liquidity_delta)
		} else {
			i128::add(tick.liquidity_net, liquidity_delta)
		};

		flipped
    }

	public fun get_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        index: I32
    ): &Tick {
        assert!(df::exists_(&pool.id, index), TickNotFound);
        let tick = df::borrow<I32, Tick>(&pool.id, index);

        tick
	}

	fun init_tick<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        index: I32,
		ctx: &mut TxContext,
	): &mut Tick {
        df::add(&mut pool.id, index, Tick {
			id: object::new(ctx),
			liquidity_gross: 0,
        	liquidity_net: i128::zero(),
        	fee_growth_outside_a: 0,
			fee_growth_outside_b: 0,
        	initialized: false,
		});

		df::borrow_mut<I32, Tick>(&mut pool.id, index)
    }

	fun cross_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
        fee_growth_global_a: u128,
		fee_growth_global_b: u128,
        ctx: &mut TxContext,
    ): I128 {
		let tick;
		if (!df::exists_(&pool.id, tick_index)) {
			tick = init_tick(pool, tick_index, ctx);
		} else {
			tick = df::borrow_mut<I32, Tick>(&mut pool.id, tick_index);
		};

		tick.fee_growth_outside_a = fee_growth_global_a - tick.fee_growth_outside_a;
        tick.fee_growth_outside_b = fee_growth_global_b - tick.fee_growth_outside_b;

        tick.liquidity_net
    }

    fun clear_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
        _ctx: &mut TxContext,
    ) {
        let tick = df::borrow_mut<I32, Tick>(&mut pool.id, tick_index);
		tick.liquidity_gross = 0;
		tick.liquidity_net = i128::zero();
		tick.fee_growth_outside_a = 0;
		tick.fee_growth_outside_b = 0;
		tick.initialized = false;
    }

    fun flip_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
        _ctx: &mut TxContext,
    ) {
		// ensure that the tick is spaced
		assert!(i32::eq(i32::mod_euclidean(tick_index, i32::from(pool.tick_spacing)), i32::zero()), EInvildTickIndex);
		let next = i32::div(tick_index, i32::from(pool.tick_spacing));
        let (word_pos, bit_pos) = position_tick(next);
        let mask: u256 = 1u256 << bit_pos;
		try_init_tick_word(pool, word_pos);
		let word = get_tick_word_mut(pool, word_pos);
        *word = *word^mask;
    }

    fun get_fee_growth_inside<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_lower_index: I32,
        tick_upper_index: I32,
        tick_current_index: I32,
        _ctx: &mut TxContext,
    ): (u128, u128) {
		let tick_lower = get_tick(pool, tick_lower_index);
		let tick_upper = get_tick(pool, tick_upper_index);
        // calculate fee growth below
        let fee_growth_below_a;
        let fee_growth_below_b;
        if (i32::gte(tick_current_index, tick_lower_index)) {
            fee_growth_below_a = tick_lower.fee_growth_outside_a;
            fee_growth_below_b = tick_lower.fee_growth_outside_b;
        } else {
            fee_growth_below_a = pool.fee_growth_global_a - tick_lower.fee_growth_outside_a;
            fee_growth_below_b = pool.fee_growth_global_b - tick_lower.fee_growth_outside_b;
        };

        // calculate fee growth above
        let fee_growth_above_a;
        let fee_growth_above_b;
        if (i32::lt(tick_current_index, tick_upper_index)) {
            fee_growth_above_a = tick_upper.fee_growth_outside_a;
            fee_growth_above_b = tick_upper.fee_growth_outside_b;
        } else {
            fee_growth_above_a = pool.fee_growth_global_a - tick_upper.fee_growth_outside_a;
            fee_growth_above_b = pool.fee_growth_global_b - tick_upper.fee_growth_outside_b;
        };

        let fee_growth_inside_a = pool.fee_growth_global_a - fee_growth_below_a - fee_growth_above_a;
        let fee_growth_inside_b = pool.fee_growth_global_b - fee_growth_below_b - fee_growth_above_b;

		(fee_growth_inside_a, fee_growth_inside_b)
    }

    fun update_position_metadata<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        position_key: String,
        liquidity_delta: I128,
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        _ctx: &mut TxContext,
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

    public fun get_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): &Position {
        get_position_by_key(pool, get_position_key(owner, tick_lower_index, tick_upper_index))
    }

    fun get_position_mut<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): &mut Position {
        get_position_mut_by_key(pool, get_position_key(owner, tick_lower_index, tick_upper_index))
    }

    fun get_position_by_key<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String
    ): &Position {
        dof::borrow<String, Position>(&pool.id, key)
    }

    fun get_position_mut_by_key<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
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
            i32::abs_u32(tick_lower_index),
            i32::is_neg(tick_lower_index),
            i32::abs_u32(tick_upper_index),
            i32::is_neg(tick_upper_index)
        )
    }

    public fun get_pool_fee<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): u32 {
        pool.fee
    }

    public fun get_pool_sqrt_price<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): u128 {
        pool.sqrt_price
    }

    public fun get_position_fee_growth_inside_a<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String
    ): u128 {
        let position = get_position_by_key(pool, key);
        position.fee_growth_inside_a
    }

    public fun get_position_fee_growth_inside_b<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String
    ): u128 {
        let position = get_position_by_key(pool, key);
        position.fee_growth_inside_b
    }

	public(friend) fun merge_coin<CoinType>(
        coins: vector<Coin<CoinType>>, 
    ): Coin<CoinType> {
        let self = vector::pop_back(&mut coins);
        pay::join_vec(&mut self, coins);
        
		self
    }

    public(friend) fun transfer_in<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coin_a: Coin<CoinTypeA>, 
        coin_b: Coin<CoinTypeB>, 
    ) {
        balance::join(&mut pool.coin_a, coin::into_balance(coin_a));
        balance::join(&mut pool.coin_b, coin::into_balance(coin_b));
    }

    public(friend) fun transfer_out<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
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

    public(friend) fun split_and_transfer<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
        coin_a: Coin<CoinTypeA>, 
		amount_a: u64,
		coin_b: Coin<CoinTypeB>, 
		amount_b: u64,
        ctx: &mut TxContext
    ) {
        let left_a = coin::split(&mut coin_a, amount_a, ctx);

        let left_b = coin::split(&mut coin_b, amount_b, ctx);

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

	public(friend) fun swap_coin_a_b<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
        coin_a: Coin<CoinTypeA>, 
		amount_in: u64,
		amount_out: u64, 
		recipient: address,
        ctx: &mut TxContext
    ) {
		//transfer a in pool_a
        let coin_in = coin::split(&mut coin_a, amount_in, ctx);
		balance::join(&mut pool.coin_a, coin::into_balance(coin_in));

		//transfer b from pool_a to recipient
		let amount_out_balance = balance::split(&mut pool.coin_b, amount_out);
        let amount_out_coin = coin::from_balance(amount_out_balance, ctx);
        transfer::transfer(amount_out_coin, recipient);

		if (coin::value(&coin_a) == 0) {
            coin::destroy_zero(coin_a);
        } else {
            transfer::transfer(
                coin_a,
                tx_context::sender(ctx)
            );
        };
    }

    public(friend) fun swap_coin_b_a<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
        coin_b: Coin<CoinTypeB>, 
		amount_in: u64,
		amount_out: u64, 
		recipient: address,
        ctx: &mut TxContext
    ) {
		//transfer a in pool_a
        let coin_in = coin::split(&mut coin_b, amount_in, ctx);
		balance::join(&mut pool.coin_b, coin::into_balance(coin_in));

		//transfer b from pool_a to recipient
		let amount_out_balance = balance::split(&mut pool.coin_a, amount_out);
        let amount_out_coin = coin::from_balance(amount_out_balance, ctx);
        transfer::transfer(amount_out_coin, recipient);

		if (coin::value(&coin_b) == 0) {
            coin::destroy_zero(coin_b);
        } else {
            transfer::transfer(
                coin_b,
                tx_context::sender(ctx)
            );
        };
    }

	public(friend) entry fun swap_coin_a_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
		pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
		coin_a: Coin<CoinTypeA>, 
		amount_in: u64,
		amount_mid: u64,
		amount_out: u64,
        recipient: address,
		ctx: &mut TxContext
    ) {
		//transfer a in pool_a
        let coin_in = coin::split(&mut coin_a, amount_in, ctx);
		balance::join(&mut pool_a.coin_a, coin::into_balance(coin_in));

		//transer b from pool_a to pool_b
		let balance_mid = balance::split(&mut pool_a.coin_b, amount_mid);
		let coin_mid = coin::from_balance(balance_mid, ctx);
		balance::join(&mut pool_b.coin_a, coin::into_balance(coin_mid));

		//transfer c from pool_b to recipient
		let balance_out = balance::split(&mut pool_b.coin_b, amount_out);
        let coin_out = coin::from_balance(balance_out, ctx);
        transfer::transfer(coin_out, recipient);

		if (coin::value(&coin_a) == 0) {
            coin::destroy_zero(coin_a);
        } else {
            transfer::transfer(
                coin_a,
                tx_context::sender(ctx)
            );
        };
	}

    public fun get_pool_balance<CoinTypeA, CoinTypeB, FeeType>(
		pool: &Pool<CoinTypeA, CoinTypeB, FeeType>, 
	): (u64, u64) {
        (
			balance::value<CoinTypeA>(&pool.coin_a),
			balance::value<CoinTypeB>(&pool.coin_b),
		)
    }

    #[test_only]
    public fun get_pool_tick_current_index<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): I32 {
        pool.tick_current_index
    }

	#[test_only]
    public fun get_pool_info<CoinTypeA, CoinTypeB, FeeType>(
		pool: &Pool<CoinTypeA, CoinTypeB, FeeType>, 
	): (u64, u64, u64, u64, u128, I32, u32, u128, u32, u32, u128, u128, u128) {
        (
			balance::value<CoinTypeA>(&pool.coin_a),
			balance::value<CoinTypeB>(&pool.coin_b),
			pool.protocol_fees_a,
			pool.protocol_fees_b,
			pool.sqrt_price,
			pool.tick_current_index,
			pool.tick_spacing,
			pool.max_liquidity_per_tick,
			pool.fee,
			pool.fee_protocol,
			pool.fee_growth_global_a,
			pool.fee_growth_global_b,
			pool.liquidity
		)
    }

    #[test_only]
	public fun get_tick_info<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
    ): (u128, I128, u128, u128, bool) {
        if (!df::exists_(&pool.id, tick_index)) return (0, i128::zero(), 0, 0, false);

        let tick = get_tick(pool, tick_index);
		(
			tick.liquidity_gross,
			tick.liquidity_net,
			tick.fee_growth_outside_a,
			tick.fee_growth_outside_b,
			tick.initialized
		)
    }

	#[test_only]
	public fun get_position_info<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): (u128, u128, u128, u64, u64) {
        let position = get_position(pool, owner, tick_lower_index, tick_upper_index);
		(
			position.liquidity,
			position.fee_growth_inside_a,
			position.fee_growth_inside_b,
			position.tokens_owed_a,
			position.tokens_owed_b
		)
    }

    #[test_only]
	public fun tick_is_initialized<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		tick_index: I32
	): bool {
		let (next_index, initialized) = next_initialized_tick_within_one_word(
			pool,
			tick_index,
			true
		);
		if (i32::eq(next_index, tick_index)) initialized else false
	}

    #[test_only]
    public fun next_initialized_tick_within_one_word_for_testing<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		tick_current_index: I32,
		lte: bool
	): (I32, bool) {
        next_initialized_tick_within_one_word(pool, tick_current_index, lte)
    }

    #[test_only]
    public fun flip_tick_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
        ctx: &mut TxContext,
    ) {
        flip_tick(pool, tick_index, ctx)
    }

    #[test_only]
    public fun collect_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a_requested: u64,
        amount_b_requested: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        collect(
            pool, 
            tick_lower_index, 
            tick_upper_index, 
            amount_a_requested, 
            amount_b_requested, 
        ctx)
    }

    #[test_only]
    public fun mint_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: u128,
        ctx: &mut TxContext,
    ): (u64, u64) {
        mint(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            liquidity_delta,
            ctx
        )
    }

    #[test_only]
    public fun burn_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: u128,
        ctx: &mut TxContext
    ): (u64, u64) {
        burn(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            liquidity_delta,
            ctx
        )
    }

    #[test_only]
    public fun swap_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        a_for_b: bool,
        amount_specified: I128,
        sqrt_price_limit: u128,
        ctx: &mut TxContext
    ): (I128, I128) {
        swap(
            pool,
            a_for_b,
            amount_specified,
            sqrt_price_limit,
            ctx
        )
    }
}