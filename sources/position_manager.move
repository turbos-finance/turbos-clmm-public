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
    
    const EFeeNotExists: u64 = 0;
	const EInvalidFee: u64 = 1;
	const EInvalidTicKSpacing: u64 = 2;
    const EFeeAlreadyExists: u64 = 3;
    const ENoCoins: u64 = 4;

	struct Position has key, store {
        id: UID,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity: u128,
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        tokens_owed_a: u128,
        tokens_owed_b: u128,
    }

	struct Positions has key, store {
        id: UID,
		nft_minted: u64
        //user_position: VecMap<address, vector<ID>>,
    }

	struct Collectible has key, store {
        id: UID,
        img_url: String,
    }

	fun init(ctx: &mut TxContext) {
		transfer::share_object(Positions {
			id: object::new(ctx),
			nft_minted: 0,
		});
    }

	public fun mint_nft(positions: &mut Positions, ctx: &mut TxContext): address {
		let c = Collectible {
			id: object::new(ctx),
			img_url: utf8(b"https://turbos.finance/"),
		};
		positions.nft_minted = positions.nft_minted + 1;
		let token_address = object::uid_to_address(&c.id);
		transfer(c, tx_context::sender(ctx));

		token_address
	}

	public fun burn_nft(c: Collectible, ctx: &mut TxContext) {
		let Collectible { id, img_url: _} = c;
		object::delete(id)
	}

    public entry fun mint<CoinTypeA, CoinTypeB>(
		pool: &mut Pool<CoinTypeA, CoinTypeB>,
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
        amount_a_min: u128,
        amount_b_min: u128,
        recipient: address,
        deadline: u128,
		ctx: &mut TxContext
    ) {
		assert!(vector::length(&coins_a) > 0, ENoCoins);
		assert!(vector::length(&coins_b) > 0, ENoCoins);
		let owner = tx_context::sender(ctx);
		let tick_lower_index_i32 = i32::from_u32_neg(tick_lower_index, tick_lower_index_is_neg);
		let tick_upper_index_i32 = i32::from_u32_neg(tick_upper_index, tick_upper_index_is_neg);

		let (liquidity_delta, amount_a, amount_b) = pool::add_liquidity(
			pool,
			merge_coin<CoinTypeA>(coins_a),
			merge_coin<CoinTypeB>(coins_b),
			fee,
			owner,
			tick_lower_index_i32,
			tick_upper_index_i32,
			amount_a_desired,
			amount_b_desired,
			amount_a_min,
			amount_b_min,
			ctx,
		);

		//mint nft
		let token_address = mint_nft(positions, ctx);
		let position_key = pool::get_position_key(owner, tick_lower_index_i32, tick_upper_index_i32);
		//create posision
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

		dof::add<address, Position>(&mut positions.id, token_address, position_m);
    }

	fun merge_coin<CoinType>(
        coins: vector<Coin<CoinType>>, 
    ): Coin<CoinType> {
        let self = vector::pop_back(&mut coins);
        pay::join_vec(&mut self, coins);
        
		self
    }
}