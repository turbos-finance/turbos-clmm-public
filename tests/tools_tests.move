// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::tools_tests {
	use sui::coin::{Coin};
    use std::vector;
    use sui::test_scenario::{Self, Scenario};
	use sui::transfer;
    use turbos_token::btc::{Self, BTC};
	use turbos_token::usdc::{Self, USDC};
    use turbos_token::eth::{Self, ETH};
    use sui::coin::{Self, TreasuryCap};
    use turbos_clmm::fee500bps::{Self};
    use turbos_clmm::fee3000bps::{Self};
    use turbos_clmm::fee10000bps::{Self};
    use turbos_clmm::pool_factory;
    use turbos_clmm::i32::{I32};
    use turbos_clmm::pool::{Self, Pool};

	const MAX_TICK_INDEX: u32 = 443636;

    public fun coin_to_vec<T>(coin: Coin<T>): vector<Coin<T>> {
        let self = vector::empty<Coin<T>>();
        vector::push_back(&mut self, coin);
        self
    }

    public fun init_pool_factory(
        admin: address,
        scenario: &mut Scenario,
    ){
        test_scenario::next_tx(scenario, admin);
		{
            pool_factory::init_for_testing(test_scenario::ctx(scenario));
        };
    }

    public fun init_tests_coin(
		admin: address,
		player: address,
		_player2: address, 
        init_amount: u64,
		scenario: &mut Scenario,
	) {
        // create btc coin
        test_scenario::next_tx(scenario, admin);
        {
            btc::init_for_testing(test_scenario::ctx(scenario));
        };

		// create usdc coin
        test_scenario::next_tx(scenario, admin);
        {
            usdc::init_for_testing(test_scenario::ctx(scenario));
        };

        // create eth coin
        test_scenario::next_tx(scenario, admin);
        {
            eth::init_for_testing(test_scenario::ctx(scenario));
        };

        // mint btc to player
        test_scenario::next_tx(scenario, admin);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<BTC>>(scenario);
            let coins = coin::mint(&mut treasury_cap, init_amount, test_scenario::ctx(scenario));
            transfer::public_transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

		// mint usdc to player
        test_scenario::next_tx(scenario, admin);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<USDC>>(scenario);
            let coins = coin::mint(&mut treasury_cap, init_amount, test_scenario::ctx(scenario));
            transfer::public_transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        // mint eth to player
        test_scenario::next_tx(scenario, admin);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<ETH>>(scenario);
            let coins = coin::mint(&mut treasury_cap, init_amount, test_scenario::ctx(scenario));
            transfer::public_transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };
	}

    public fun init_fee_type(
        admin: address,
        scenario: &mut Scenario,
    ) {
        //init fee type
        test_scenario::next_tx(scenario, admin);
        {
            fee500bps::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            fee3000bps::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            fee10000bps::init_for_testing(test_scenario::ctx(scenario));
        };
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

    public fun get_pool_tick_index<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): I32 {
        let (_,_,_,_,_,tick_current_index,_,_,_,_,_,_,_,) = pool::get_pool_info(pool);

        tick_current_index
    }
    
    public fun get_pool_sqrt_price<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): u128 {
        let (_,_,_,_,sqrt_price,_,_,_,_,_,_,_,_,) = pool::get_pool_info(pool);

        sqrt_price
    }

    public fun get_pool_fee_growth_global<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): (u128, u128) {
        let (_,_,_,_,_,_,_,_,_,_,fee_growth_global_a,fee_growth_global_b,_,) = pool::get_pool_info(pool);

        (fee_growth_global_a, fee_growth_global_b)
    }

    public fun get_pool_protocol_fees<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): (u64, u64) {
        let (_,_,protocol_fees_a,protocol_fees_b,_,_,_,_,_,_,_,_,_,) = pool::get_pool_info(pool);

        (protocol_fees_a, protocol_fees_b)
    }

}