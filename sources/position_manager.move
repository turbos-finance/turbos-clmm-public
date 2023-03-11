// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::position_manager {
	use std::vector;
    use sui::vec_map::{Self, VecMap};
    use sui::transfer;
    use std::string::{Self, String, utf8};
    use turbos_clmm::i32::{Self, I32};
    use turbos_clmm::i128::{Self, I128};
    use sui::table::{Self, Table};
    use turbos_clmm::string_tools;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
    use turbos_clmm::pool::{Self, Pool};
	use sui::transfer::transfer;
	use sui::coin::{Self, Coin};
	use sui::balance::{Self, Balance, Supply};
	use sui::pay;
    use turbos_clmm::full_math_u128;
    use turbos_clmm::math_liquidity;
    use turbos_clmm::math_tick;
    
    const Q64: u128 = 0x10000000000000000;
    
    const EFeeNotExists: u64 = 0;
	const EInvalidFee: u64 = 1;
	const EInvalidTicKSpacing: u64 = 2;
    const EFeeAlreadyExists: u64 = 3;
    const ENoCoins: u64 = 4;
    const EPriceSlippageCheck: u64 = 5;
    const EPositionNotCleared: u64 = 6;

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
		nft_minted: u64
        //user_position: VecMap<address, vector<ID>>,
    }

	struct TurbosPositionNFT has key, store {
        id: UID,
        img_url: String,
    }

	fun init(ctx: &mut TxContext) {
		transfer::share_object(Positions {
			id: object::new(ctx),
			nft_minted: 0,
		});
    }

    public entry fun mint<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		coins_a: vector<Coin<CoinTypeA>>, 
		coins_b: vector<Coin<CoinTypeB>>, 
		fee: u32,
		tick_lower_index: u32,
		tick_lower_index_is_neg: bool,
        tick_upper_index: u32,
		tick_upper_index_is_neg: bool,
		amount_a_desired: u128,
        amount_b_desired: u128,
        amount_a_min: u64,
        amount_b_min: u64,
        recipient: address,
        deadline: u128,
		ctx: &mut TxContext
    ) {
		assert!(vector::length(&coins_a) > 0, ENoCoins);
		assert!(vector::length(&coins_b) > 0, ENoCoins);
		let owner = tx_context::sender(ctx);
		let tick_lower_index_i32 = i32::from_u32_neg(tick_lower_index, tick_lower_index_is_neg);
		let tick_upper_index_i32 = i32::from_u32_neg(tick_upper_index, tick_upper_index_is_neg);

		let (liquidity_delta, amount_a, amount_b) = add_liquidity(
			pool,
			merge_coin<CoinTypeA>(coins_a),
			merge_coin<CoinTypeB>(coins_b),
			fee,
			owner,
			tick_lower_index_i32,
			tick_upper_index_i32,
			amount_a_desired,
			amount_b_desired,
			ctx,
		);
        assert!(amount_a >= amount_a_min && amount_b >= amount_b_min, EPriceSlippageCheck);

		//mint nft
		let nft_address = mint_nft(positions, recipient, ctx);
		let position_key = pool::get_position_key(owner, tick_lower_index_i32, tick_upper_index_i32);
		//create position
		let position_m = Position {
			id: object::new(ctx),
			tick_lower_index: tick_lower_index_i32,
        	tick_upper_index: tick_upper_index_i32,
        	liquidity: liquidity_delta,
        	fee_growth_inside_a: pool::get_position_fee_growth_inside_a(pool, position_key),
        	fee_growth_inside_b: pool::get_position_fee_growth_inside_b(pool, position_key),
        	tokens_owed_a: 0,
        	tokens_owed_b: 0,
		};

		dof::add<address, Position>(&mut positions.id, nft_address, position_m);
    }

    public entry fun burn<CoinTypeA, CoinTypeB, FeeType>(
        positions: &mut Positions,
        nft: TurbosPositionNFT,
        ctx: &mut TxContext
    ) {
        let nft_address = object::id_address(&nft);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        assert!(position.liquidity == 0 && position.tokens_owed_a == 0 && position.tokens_owed_a == 0, EPositionNotCleared);
        burn_nft(nft, ctx);
    }

    fun add_liquidity<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        fee: u32,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a_desired: u128,
        amount_b_desired: u128,
        ctx: &mut TxContext,
    ): (u128, u64, u64) {
        let sqrt_price_a = math_tick::sqrt_price_from_tick_index(tick_lower_index);
        let sqrt_price_b = math_tick::sqrt_price_from_tick_index(tick_upper_index);
        let sqrt_price = pool::get_pool_sqrt_price(pool);

        let liquidity_delta = math_liquidity::get_liquidity_for_amounts(
            sqrt_price,
            sqrt_price_a,
            sqrt_price_b,
            amount_a_desired,
            amount_b_desired
        );

        let (amount_a, amount_b) = pool::mint(
            pool,
            coin_a,
            coin_b,
            recipient,
            tick_lower_index,
            tick_upper_index,
            liquidity_delta,
            ctx,
        );

        (liquidity_delta, amount_a, amount_b)
    }

    public entry fun increase_liquidity<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		coins_a: vector<Coin<CoinTypeA>>, 
		coins_b: vector<Coin<CoinTypeB>>, 
		nft: &mut TurbosPositionNFT,
		amount_a_desired: u128,
        amount_b_desired: u128,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u128,
		ctx: &mut TxContext
    ) {
		assert!(vector::length(&coins_a) > 0, ENoCoins);
		assert!(vector::length(&coins_b) > 0, ENoCoins);
        let nft_address = object::id_address(nft);
		let owner = tx_context::sender(ctx);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        let fee = pool::get_pool_fee(pool);

		let (liquidity_delta, amount_a, amount_b) = add_liquidity(
			pool,
			merge_coin<CoinTypeA>(coins_a),
			merge_coin<CoinTypeB>(coins_b),
			fee,
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

        position.tokens_owed_a = position.tokens_owed_a + amount_a + tokens_owed_a;
        position.tokens_owed_b = position.tokens_owed_b + amount_b + tokens_owed_b;
        position.fee_growth_inside_a = fee_growth_inside_a;
        position.fee_growth_inside_b = fee_growth_inside_b;
        position.liquidity = position.liquidity + liquidity_delta;
    }

    public entry fun decrease_liquidity<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		nft: &mut TurbosPositionNFT,
		liquidity: u128,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u128,
		ctx: &mut TxContext
    ) {
        let nft_address = object::id_address(nft);
		let owner = tx_context::sender(ctx);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);

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

        position.tokens_owed_a = position.tokens_owed_a + amount_a + tokens_owed_a;
        position.tokens_owed_b = position.tokens_owed_b + amount_b + tokens_owed_b;
        position.fee_growth_inside_a = fee_growth_inside_a;
        position.fee_growth_inside_b = fee_growth_inside_b;
        position.liquidity = position.liquidity - liquidity;
    }

    public entry fun collect<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		nft: &mut TurbosPositionNFT,
        amount_a_max: u64,
        amount_b_max: u64,
        recipient: address,
        deadline: u128,
		ctx: &mut TxContext
    ) {
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

        position.tokens_owed_a = position.tokens_owed_a - amount_a_collect;
        position.tokens_owed_b = position.tokens_owed_b - amount_b_collect;
    }

	fun mint_nft(
        positions: &mut Positions,
        recipient: address,
        ctx: &mut TxContext
    ): address {
		let nft = TurbosPositionNFT {
			id: object::new(ctx),
			img_url: utf8(b"https://turbos.finance/"),
		};
		positions.nft_minted = positions.nft_minted + 1;
		let nft_address = object::uid_to_address(&nft.id);
		transfer(nft, recipient);

		nft_address
	}

	fun burn_nft(nft: TurbosPositionNFT, ctx: &mut TxContext) {
		let TurbosPositionNFT { id, img_url: _} = nft;
		object::delete(id)
	}

	public fun merge_coin<CoinType>(
        coins: vector<Coin<CoinType>>, 
    ): Coin<CoinType> {
        let self = vector::pop_back(&mut coins);
        pay::join_vec(&mut self, coins);
        
		self
    }
}