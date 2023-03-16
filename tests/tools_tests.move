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
		player2: address, 
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
            transfer::transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

		// mint usdc to player
        test_scenario::next_tx(scenario, admin);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<USDC>>(scenario);
            let coins = coin::mint(&mut treasury_cap, init_amount, test_scenario::ctx(scenario));
            transfer::transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        // mint eth to player
        test_scenario::next_tx(scenario, admin);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<ETH>>(scenario);
            let coins = coin::mint(&mut treasury_cap, init_amount, test_scenario::ctx(scenario));
            transfer::transfer(coins, copy player2);
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

}