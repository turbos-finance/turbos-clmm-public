// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::pool_factory {
	use std::vector;
    use sui::vec_map::{Self, VecMap};
    use sui::transfer;
    use std::string::{Self, String};
    use turbos_clmm::i32::{Self, I32};
    use turbos_clmm::i128::{Self, I128};
    use sui::table::{Self, Table};
    use turbos_clmm::string_tools;
    use turbos_clmm::fee::{Self, Fee};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
    use turbos_clmm::pool;
    use sui::balance::{Self, Supply, Balance};
    
    const EFeeNotExists: u64 = 0;
	const EInvalidFee: u64 = 1;
	const EInvalidTicKSpacing: u64 = 2;
    const EFeeAlreadyExists: u64 = 3;


	struct AdminCap has key, store { id: UID }

    struct PoolConfig has key, store {
        id: UID,
        fee_amount_tick_spacing: VecMap<u32, u32>,
		pools: vector<ID>,
    }

	fun init(ctx: &mut TxContext) {
		let fee_amount_tick_spacing = vec_map::empty<u32, u32>();
		vec_map::insert(&mut fee_amount_tick_spacing, 500, 10);
		vec_map::insert(&mut fee_amount_tick_spacing, 3000, 60);
		vec_map::insert(&mut fee_amount_tick_spacing, 10000, 200);
        let pool_config = PoolConfig {
			id: object::new(ctx), 
			fee_amount_tick_spacing: fee_amount_tick_spacing,
			pools: vector::empty(),
		};

		transfer::share_object(pool_config);
		transfer::transfer(AdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    public entry fun deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
		pool_config: &mut PoolConfig,
		feeType: &Fee<FeeType>,
		sqrt_price: u128,
		ctx: &mut TxContext
    ) {
		let fee = fee::get_fee(feeType);
        let key = fee;
		assert!(vec_map::contains(&pool_config.fee_amount_tick_spacing, &key), EFeeNotExists);
		let tick_spacing = vec_map::get(&pool_config.fee_amount_tick_spacing, &key);

		let pool = pool::deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
            fee,
            *tick_spacing,
            sqrt_price,
            ctx);
		vector::push_back(&mut pool_config.pools, object::id(&pool));
        transfer::share_object(pool);
    }

	public entry fun enable_fee_amount(
		_: &AdminCap,
		pool_config: &mut PoolConfig,
		fee: u32,
		tick_spacing: u32,
	) {
		let key = fee;
		assert!(fee < 1000000, EInvalidFee);
		assert!(tick_spacing > 0 && tick_spacing < 16384, EInvalidTicKSpacing);
		assert!(!vec_map::contains(&pool_config.fee_amount_tick_spacing, &key), EFeeAlreadyExists);
		vec_map::insert(&mut pool_config.fee_amount_tick_spacing, fee, tick_spacing);
	}
}