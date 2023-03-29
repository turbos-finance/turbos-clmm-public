// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::pool_factory {
	use std::vector;
	use sui::event;
    use sui::vec_map::{Self, VecMap};
    use sui::transfer;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
	use sui::coin::{Coin};
    use turbos_clmm::pool;
	use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::fee::{Self, Fee};
    
    const EFeeNotExists: u64 = 0;
	const EInvalidFee: u64 = 1;
	const EInvalidTicKSpacing: u64 = 2;
    const EFeeAlreadyExists: u64 = 3;

	struct PoolFactoryAdminCap has key, store { id: UID }

    struct PoolConfig has key, store {
        id: UID,
        fee_amount_tick_spacing: VecMap<u32, u32>,
		fee_protocol: u32,
		pools: vector<ID>,
    }

	struct PoolCreatedEvent has copy, drop {
        account: address,
        pool: ID,
        fee: u32,
        tick_spacing: u32,
        fee_protocol: u32,
		sqrt_price: u128,
    }

	struct FeeAmountEnabledEvent has copy, drop {
		fee: u32,
		tick_spacing: u32,
	}

	fun init(ctx: &mut TxContext) {
        init_(ctx);
    }

	fun init_(ctx: &mut TxContext) {
		let fee_amount_tick_spacing = vec_map::empty<u32, u32>();
		vec_map::insert(&mut fee_amount_tick_spacing, 500, 10);
		event::emit(FeeAmountEnabledEvent {fee: 500, tick_spacing: 10});
		vec_map::insert(&mut fee_amount_tick_spacing, 3000, 60);
		event::emit(FeeAmountEnabledEvent {fee: 3000, tick_spacing: 60});
		vec_map::insert(&mut fee_amount_tick_spacing, 10000, 200);
		event::emit(FeeAmountEnabledEvent {fee: 10000, tick_spacing: 200});

        let pool_config = PoolConfig {
			id: object::new(ctx), 
			fee_amount_tick_spacing: fee_amount_tick_spacing,
			fee_protocol: 0,
			pools: vector::empty(),
		};

		transfer::share_object(pool_config);
		transfer::transfer(PoolFactoryAdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

	public entry fun deploy_pool_and_mint<CoinTypeA, CoinTypeB, FeeType>(
		pool_config: &mut PoolConfig,
		feeType: &Fee<FeeType>,
		sqrt_price: u128,
		positions: &mut Positions,
		coins_a: vector<Coin<CoinTypeA>>, 
		coins_b: vector<Coin<CoinTypeB>>, 
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
		let fee = fee::get_fee(feeType);
        let key = fee;
		assert!(vec_map::contains(&pool_config.fee_amount_tick_spacing, &key), EFeeNotExists);
		let tick_spacing = *vec_map::get(&pool_config.fee_amount_tick_spacing, &key);

		let pool = pool::deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
            fee,
            tick_spacing,
            sqrt_price,
			pool_config.fee_protocol,
            ctx);

		event::emit(PoolCreatedEvent {
			account: tx_context::sender(ctx),
			pool: object::id(&pool),
			fee: fee,
			tick_spacing: tick_spacing,
			fee_protocol: pool_config.fee_protocol,
			sqrt_price: sqrt_price,
		});

		position_manager::mint(
			&mut pool,
			positions,
			coins_a,
			coins_b,
			tick_lower_index,
			tick_lower_index_is_neg,
			tick_upper_index,
			tick_upper_index_is_neg,
			amount_a_desired,
			amount_b_desired,
			amount_a_min,
			amount_b_min,
			recipient,
			deadline,
			ctx
		);

		vector::push_back(&mut pool_config.pools, object::id(&pool));
        transfer::public_share_object(pool);

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
		let tick_spacing = *vec_map::get(&pool_config.fee_amount_tick_spacing, &key);

		let pool = pool::deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
            fee,
            tick_spacing,
            sqrt_price,
			pool_config.fee_protocol,
            ctx);
		vector::push_back(&mut pool_config.pools, object::id(&pool));

		event::emit(PoolCreatedEvent {
			account: tx_context::sender(ctx),
			pool: object::id(&pool),
			fee: fee,
			tick_spacing: tick_spacing,
			fee_protocol: pool_config.fee_protocol,
			sqrt_price: sqrt_price,
		});
        transfer::public_share_object(pool);
    }

	public entry fun enable_fee_amount(
		_: &PoolFactoryAdminCap,
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

	public entry fun set_fee_protocol(
		_: &PoolFactoryAdminCap,
		pool_config: &mut PoolConfig,
		fee_protocol: u32,
	) {
		assert!(fee_protocol < 1000000, EInvalidFee);
		pool_config.fee_protocol = fee_protocol;
	}

	#[test_only]
	public fun mock_init_for_testing(ctx: &mut TxContext) {
		let fee_amount_tick_spacing = vec_map::empty<u32, u32>();
		vec_map::insert(&mut fee_amount_tick_spacing, 500, 10);
		vec_map::insert(&mut fee_amount_tick_spacing, 3000, 60);
		vec_map::insert(&mut fee_amount_tick_spacing, 10000, 1);
        let pool_config = PoolConfig {
			id: object::new(ctx), 
			fee_amount_tick_spacing: fee_amount_tick_spacing,
			fee_protocol: 2500,
			pools: vector::empty(),
		};

		transfer::share_object(pool_config);
		transfer::transfer(PoolFactoryAdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init_(ctx);
    }
}