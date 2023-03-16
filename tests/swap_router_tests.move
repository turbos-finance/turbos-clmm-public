// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::swap_router_tests {
    use std::vector;
    use sui::test_utils::{assert_eq};
	use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self, Scenario};
    use turbos_token::btc::{BTC};
	use turbos_token::usdc::{USDC};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::pool::{Self, Pool};
    use turbos_clmm::tools_tests;
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::math_tick;
    use turbos_clmm::fee::{Self, Fee};
	use turbos_clmm::swap_router;
	use turbos_clmm::position_manager_tests;
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::math_sqrt_price::{Self};

	const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;

    fun prepare_tests(
        admin: address,
		player: address,
		player2: address, 
		scenario: &mut Scenario,
    ) {
        tools_tests::init_fee_type(
            admin,
            scenario
        );

        tools_tests::init_tests_coin(
            admin,
            player,
            player2,
            2000000,
            scenario
        );

        tools_tests::init_pool_factory(
            admin,
            scenario
        );

        //init BTCUSDC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            //price=1, 1btc = 1usdc
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<BTC, USDC, FEE3000BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                test_scenario::ctx(scenario),
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
        };

        //add liquidity
		test_scenario::next_tx(scenario, player);
        {
			let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let fee = fee::get_fee<FEE3000BPS>(&fee_type);
            let min_tick_index = math_tick::get_min_tick(fee);
            let max_tick_index = math_tick::get_max_tick(fee);

            //btc
            position_manager::mint<BTC, USDC, FEE3000BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                1000000,
                1000000,
                0,
                0,
                player,
                1,
                test_scenario::ctx(scenario),
            );

			test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
		};
    }

	#[test]
	public fun test_swap_a_b() {
		let admin = @0x0;
        let player = @0x1;
		let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

		position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

		// swap btc to usdc
        let (balance_a_before, balance_b_before);
        let (trader_balance_a_before, trader_balance_b_before);
		test_scenario::next_tx(scenario, player);
        {
			let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);

            //pool balance before
            (balance_a_before, balance_b_before) = pool::get_pool_balance(&mut pool_a);

            //get trader balance before
            let coins;
            (coins, trader_balance_a_before) = get_user_coin<BTC>(scenario);
            trader_balance_b_before = get_user_coin_balance<USDC>(scenario);

            //swap 100 btc to 1000 usdc
			swap_router::swap_a_b(
				&mut pool_a,
				coins,
				3, //amount_in 
				1, //amount_out_min
				MIN_SQRT_PRICE_X64 + 1,
				player,
				1,
				test_scenario::ctx(scenario),
			);

			test_scenario::return_shared(pool_a);
		};

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let (balance_a_after, balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let trader_balance_a_after = get_user_coin_balance<BTC>(scenario);
            let trader_balance_b_after = get_user_coin_balance<USDC>(scenario);

            assert_eq(balance_a_after - balance_a_before, 3);
            assert_eq(balance_b_before - balance_b_after, 1);
            assert_eq(trader_balance_a_before - trader_balance_a_after, 3);
            assert_eq(trader_balance_b_after - trader_balance_b_before, 1);

            test_scenario::return_shared(pool_a);
        };

		test_scenario::end(scenario_val);
	}

    public fun get_user_coin_balance<T>(
        scenario: &mut Scenario,
    ): u64 {
        let coin_ids = test_scenario::ids_for_sender<Coin<T>>(scenario);
        let trader_balance_a = 0;
        while (!vector::is_empty(&coin_ids)) {
            let coin = test_scenario::take_from_sender_by_id<Coin<T>>(scenario, vector::pop_back(&mut coin_ids));
            trader_balance_a = trader_balance_a + coin::value(&coin);
            test_scenario::return_to_sender(scenario, coin);
        };

        trader_balance_a
    }

    public fun get_user_coin_vec<T>(
        scenario: &mut Scenario,
    ): vector<Coin<T>> {
        let coin_ids = test_scenario::ids_for_sender<Coin<T>>(scenario);
        let coins = vector::empty<Coin<T>>();
        while (!vector::is_empty(&coin_ids)) {
            let coin = test_scenario::take_from_sender_by_id<Coin<T>>(scenario, vector::pop_back(&mut coin_ids));
            vector::push_back(&mut coins, coin);
        };

        coins
    }

    public fun get_user_coin<T>(
        scenario: &mut Scenario,
    ): (vector<Coin<T>>, u64) {
        let coin_ids = test_scenario::ids_for_sender<Coin<T>>(scenario);
        let coins = vector::empty<Coin<T>>();
        let trader_balance_a = 0;
        while (!vector::is_empty(&coin_ids)) {
            let coin = test_scenario::take_from_sender_by_id<Coin<T>>(scenario, vector::pop_back(&mut coin_ids));
            trader_balance_a = trader_balance_a + coin::value(&coin);
            vector::push_back(&mut coins, coin);
        };

        (coins, trader_balance_a)
    }
}