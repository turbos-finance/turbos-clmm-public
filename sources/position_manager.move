// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::position_manager {
	use std::vector;
    use sui::transfer;
    use sui::event;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
	use sui::coin::{Coin};
    use sui::table::{Self, Table};
    use turbos_clmm::i32::{Self, I32};
    use turbos_clmm::full_math_u128;
    use turbos_clmm::math_liquidity;
    use turbos_clmm::math_tick;
    use turbos_clmm::pool::{Self, Pool};
    use turbos_clmm::position_nft::{Self, TurbosPositionNFT};
    use sui::clock::{Self, Clock};
    
    const Q64: u128 = 0x10000000000000000;
    
    const EFeeNotExists: u64 = 0;
	const EInvalidFee: u64 = 1;
	const EInvalidTicKSpacing: u64 = 2;
    const EFeeAlreadyExists: u64 = 3;
    const ENoCoins: u64 = 4;
    const EPriceSlippageCheck: u64 = 5;
    const EPositionNotCleared: u64 = 6;
    const EInvildMintAmount: u64 = 7;
    const ETransactionToOld: u64 = 8;
    const EInsufficientLiquidity: u64 = 9;

	struct Position has key, store {
        id: UID,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity: u128,
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        tokens_owed_a: u64,
        tokens_owed_b: u64,
    }

	struct Positions has key, store {
        id: UID,
		nft_minted: u64,
        user_position: Table<address, ID>,
    }

    struct IncreaseLiquidityEvent has copy, drop {
        pool: ID,
        amount_a: u64,
        amount_b: u64,
        liquidity: u128,
    }

    struct DecreaseLiquidityEvent has copy, drop {
        pool: ID,
        amount_a: u64,
        amount_b: u64,
        liquidity: u128,
    }

    struct CollectEvent has copy, drop {
        pool: ID,
        amount_a: u64,
        amount_b: u64,
        recipient: address,
    }

	fun init(ctx: &mut TxContext) {
		init_(ctx);
    }

    fun init_(ctx: &mut TxContext) {
		transfer::share_object(Positions {
			id: object::new(ctx),
			nft_minted: 0,
            user_position: table::new(ctx),
		});
    }

    public entry fun mint<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		coins_a: vector<Coin<CoinTypeA>>, 
		coins_b: vector<Coin<CoinTypeB>>, 
		tick_lower_index: u32,
		tick_lower_index_is_neg: bool,
        tick_upper_index: u32,
		tick_upper_index_is_neg: bool,
		amount_a_desired: u64,
        amount_b_desired: u64,
        amount_a_min: u64,
        amount_b_min: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
		ctx: &mut TxContext
    ) {
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
		assert!(vector::length(&coins_a) > 0, ENoCoins);
		assert!(vector::length(&coins_b) > 0, ENoCoins);
		let owner = tx_context::sender(ctx);
		let tick_lower_index_i32 = i32::from_u32_neg(tick_lower_index, tick_lower_index_is_neg);
		let tick_upper_index_i32 = i32::from_u32_neg(tick_upper_index, tick_upper_index_is_neg);

		let (liquidity_delta, amount_a, amount_b) = add_liquidity(
			pool,
			pool::merge_coin<CoinTypeA>(coins_a),
			pool::merge_coin<CoinTypeB>(coins_b),
			owner,
			tick_lower_index_i32,
			tick_upper_index_i32,
			amount_a_desired,
			amount_b_desired,
			ctx,
		);
        assert!(amount_a >= amount_a_min && amount_b >= amount_b_min, EPriceSlippageCheck);

        let position_id = object::new(ctx);
		//mint nft
		let nft_address = mint_nft(
            object::id(pool), 
            object::uid_to_inner(&position_id), 
            positions, 
            recipient, 
            ctx
        );
		let position_key = pool::get_position_key(owner, tick_lower_index_i32, tick_upper_index_i32);
		//create position
        let position_inner_id = object::uid_to_inner(&position_id);
		let position_m = Position {
			id: position_id,
			tick_lower_index: tick_lower_index_i32,
        	tick_upper_index: tick_upper_index_i32,
        	liquidity: liquidity_delta,
        	fee_growth_inside_a: pool::get_position_fee_growth_inside_a(pool, position_key),
        	fee_growth_inside_b: pool::get_position_fee_growth_inside_b(pool, position_key),
        	tokens_owed_a: 0,
        	tokens_owed_b: 0,
		};
		dof::add<address, Position>(&mut positions.id, nft_address, position_m);
        insert_user_position(positions, position_inner_id, nft_address);

        event::emit(IncreaseLiquidityEvent {
            pool: object::id(pool),
            amount_a: amount_a,
            amount_b: amount_b,
            liquidity: liquidity_delta,
        });
    }

    public entry fun burn<CoinTypeA, CoinTypeB, FeeType>(
        positions: &mut Positions,
        nft: TurbosPositionNFT,
        _ctx: &mut TxContext
    ) {
        let nft_address = object::id_address(&nft);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        assert!(position.liquidity == 0 && position.tokens_owed_a == 0 && position.tokens_owed_a == 0, EPositionNotCleared);
        delete_user_position(positions, nft_address);
        burn_nft(nft);
    }

    fun add_liquidity<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a_desired: u64,
        amount_b_desired: u64,
        ctx: &mut TxContext,
    ): (u128, u64, u64) {
        let sqrt_price_a = math_tick::sqrt_price_from_tick_index(tick_lower_index);
        let sqrt_price_b = math_tick::sqrt_price_from_tick_index(tick_upper_index);
        let sqrt_price = pool::get_pool_sqrt_price(pool);

        let liquidity_delta = math_liquidity::get_liquidity_for_amounts(
            sqrt_price,
            sqrt_price_a,
            sqrt_price_b,
            (amount_a_desired as u128),
            (amount_b_desired as u128)
        );

        let (amount_a, amount_b) = pool::mint(
            pool,
            recipient,
            tick_lower_index,
            tick_upper_index,
            liquidity_delta,
            ctx,
        );

        let (balance_a_before, balance_b_before) = pool::get_pool_balance(pool);
        pool::split_and_transfer(
            pool,
            coin_a,
            amount_a,
            coin_b,
            amount_b,
            ctx,
        );
        let (balance_a_current, balance_b_current) = pool::get_pool_balance(pool);

        assert!(balance_a_before + amount_a <= balance_a_current, EInvildMintAmount);
        assert!(balance_b_before + amount_b <= balance_b_current, EInvildMintAmount);

        (liquidity_delta, amount_a, amount_b)
    }

    public entry fun increase_liquidity<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		coins_a: vector<Coin<CoinTypeA>>, 
		coins_b: vector<Coin<CoinTypeB>>, 
		nft: &mut TurbosPositionNFT,
		amount_a_desired: u64,
        amount_b_desired: u64,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u64,
        clock: &Clock,
		ctx: &mut TxContext
    ) {
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
		assert!(vector::length(&coins_a) > 0, ENoCoins);
		assert!(vector::length(&coins_b) > 0, ENoCoins);
        let nft_address = object::id_address(nft);
		let owner = tx_context::sender(ctx);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);

		let (liquidity_delta, amount_a, amount_b) = add_liquidity(
			pool,
			pool::merge_coin<CoinTypeA>(coins_a),
			pool::merge_coin<CoinTypeB>(coins_b),
			owner,
			position.tick_lower_index,
			position.tick_upper_index,
			amount_a_desired,
			amount_b_desired,
			ctx,
		);
        assert!(amount_a >= amount_a_min && amount_b >= amount_b_min, EPriceSlippageCheck);

		let position_key = pool::get_position_key(owner, position.tick_lower_index, position.tick_upper_index);
        let fee_growth_inside_a = pool::get_position_fee_growth_inside_a(pool, position_key);
        let fee_growth_inside_b = pool::get_position_fee_growth_inside_b(pool, position_key);

        let tokens_owed_a = (full_math_u128::mul_div_floor(fee_growth_inside_a - position.fee_growth_inside_a, position.liquidity, Q64) as u64);
        let tokens_owed_b = (full_math_u128::mul_div_floor(fee_growth_inside_b - position.fee_growth_inside_b, position.liquidity, Q64) as u64);

        position.tokens_owed_a = position.tokens_owed_a + tokens_owed_a;
        position.tokens_owed_b = position.tokens_owed_b + tokens_owed_b;
        position.fee_growth_inside_a = fee_growth_inside_a;
        position.fee_growth_inside_b = fee_growth_inside_b;
        position.liquidity = position.liquidity + liquidity_delta;

        event::emit(IncreaseLiquidityEvent {
            pool: object::id(pool),
            amount_a: amount_a,
            amount_b: amount_b,
            liquidity: liquidity_delta,
        });
    }

    public entry fun decrease_liquidity<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		nft: &mut TurbosPositionNFT,
		liquidity: u128,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u64,
        clock: &Clock,
		ctx: &mut TxContext
    ) {
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let nft_address = object::id_address(nft);
		let owner = tx_context::sender(ctx);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        assert!(position.liquidity >= liquidity, EInsufficientLiquidity);

		let (amount_a, amount_b) = pool::burn(
			pool,
			owner,
			position.tick_lower_index,
			position.tick_upper_index,
			liquidity,
			ctx,
		);

        assert!(amount_a >= amount_a_min && amount_b_min >= amount_b_min, EPriceSlippageCheck);

		let position_key = pool::get_position_key(owner, position.tick_lower_index, position.tick_upper_index);
        let fee_growth_inside_a = pool::get_position_fee_growth_inside_a(pool, position_key);
        let fee_growth_inside_b = pool::get_position_fee_growth_inside_b(pool, position_key);

        let tokens_owed_a = (full_math_u128::mul_div_floor(fee_growth_inside_a - position.fee_growth_inside_a, position.liquidity, Q64) as u64);
        let tokens_owed_b = (full_math_u128::mul_div_floor(fee_growth_inside_b - position.fee_growth_inside_b, position.liquidity, Q64) as u64);

        position.tokens_owed_a = position.tokens_owed_a + tokens_owed_a;
        position.tokens_owed_b = position.tokens_owed_b + tokens_owed_b;
        position.fee_growth_inside_a = fee_growth_inside_a;
        position.fee_growth_inside_b = fee_growth_inside_b;
        position.liquidity = position.liquidity - liquidity;

        pool::transfer_out(
            pool,
            amount_a,
            amount_b,
            owner,
            ctx
        );

        event::emit(DecreaseLiquidityEvent {
            pool: object::id(pool),
            amount_a: amount_a,
            amount_b: amount_b,
            liquidity: liquidity,
        });
    }

    public entry fun collect<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		nft: &mut TurbosPositionNFT,
        amount_a_max: u64,
        amount_b_max: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
		ctx: &mut TxContext
    ) {
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionToOld);
        let nft_address = object::id_address(nft);
		let owner = tx_context::sender(ctx);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        let (tokens_owed_a, tokens_owed_b) = (position.tokens_owed_a, position.tokens_owed_b);
        if (position.liquidity > 0) {
            pool::burn(
			    pool,
			    owner,
			    position.tick_lower_index,
			    position.tick_upper_index,
			    0,
			    ctx,
		    );
            let position_key = pool::get_position_key(owner, position.tick_lower_index, position.tick_upper_index);
            let fee_growth_inside_a = pool::get_position_fee_growth_inside_a(pool, position_key);
            let fee_growth_inside_b = pool::get_position_fee_growth_inside_b(pool, position_key);

            tokens_owed_a = tokens_owed_a + (full_math_u128::mul_div_floor(fee_growth_inside_a - position.fee_growth_inside_a, position.liquidity, Q64) as u64);
            tokens_owed_b = tokens_owed_b + (full_math_u128::mul_div_floor(fee_growth_inside_b - position.fee_growth_inside_b, position.liquidity, Q64) as u64);

            position.fee_growth_inside_a = fee_growth_inside_a;
            position.fee_growth_inside_b = fee_growth_inside_b;

        };

        let (amount_a_collect, amount_b_collect) =
        (
            if (amount_a_max > tokens_owed_a) tokens_owed_a else amount_a_max,
            if (amount_b_max > tokens_owed_b) tokens_owed_b else amount_b_max
        );

        let (amount_a, amount_b) = pool::collect(
            pool,
            recipient,
            position.tick_lower_index,
			position.tick_upper_index,
            amount_a_collect,
            amount_b_collect,
            ctx,
        );

        pool::transfer_out(
            pool,
            amount_a,
            amount_b,
            recipient,
            ctx
        );

        position.tokens_owed_a = position.tokens_owed_a - amount_a_collect;
        position.tokens_owed_b = position.tokens_owed_b - amount_b_collect;

        event::emit(CollectEvent {
            pool: object::id(pool),
            amount_a: amount_a,
            amount_b: amount_b,
            recipient: recipient,
        });
    }

	fun mint_nft(
        pool_id: ID,
        position_id: ID,
        positions: &mut Positions,
        recipient: address,
        ctx: &mut TxContext
    ): address {
        let nft = position_nft::mint(
            b"Turbos Position's NFT",
            b"An NFT created by Turbos CLMM",
			b"https://ipfs.io/ipfs/QmTxRsWbrLG6mkjg375wW77Lfzm38qsUQjRBj3b2K3t8q1?filename=Turbos_nft.png",
            pool_id,
            position_id,
            ctx,
        );
		positions.nft_minted = positions.nft_minted + 1;
		let nft_address = object::id_address(&nft);
		transfer::public_transfer(nft, recipient);

		nft_address
	}

	fun burn_nft(
        nft: TurbosPositionNFT
    ) {
        position_nft::burn(nft);
	}

    fun insert_user_position(
        positions: &mut Positions, 
        position_id: ID, 
        nft_address: address
    ) {
        if (!table::contains(&positions.user_position, nft_address)) {
            table::add(&mut positions.user_position, nft_address, position_id);
        }
    }

    fun delete_user_position(
        positions: &mut Positions, 
        nft_address: address
    ) {
        if (table::contains(&positions.user_position, nft_address)) {
            table::remove(&mut positions.user_position, nft_address);
        }
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init_(ctx);
    }

    #[test_only]
    public fun get_nft_minted(positions: & Positions,): u64 {
        positions.nft_minted
    }
}