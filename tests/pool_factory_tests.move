// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::pool_factory_tests {
	use sui::math;
	use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use sui::test_scenario::{Self, Scenario};
	use sui::transfer;
    use turbos_token::btc::{Self, BTC};
	use turbos_token::usdc::{Self, USDC};
    use turbos_token::eth::{Self, ETH};
    use sui::coin::{Self, Coin, TreasuryCap};
    use std::vector;
    use turbos_clmm::fee500bps::{Self, FEE500BPS};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::tools_tests;
    // use std::debug;

    fun coin_to_vec<T>(coin: Coin<T>): vector<Coin<T>> {
        let self = vector::empty<Coin<T>>();
        vector::push_back(&mut self, coin);
        self
    }

	public fun init_pools(
		admin: address,
		player: address,
		player2: address, 
		scenario: &mut Scenario,
	) {
        //init pool facotry
        test_scenario::next_tx(scenario, admin);
		{
            pool_factory::init_for_testing(test_scenario::ctx(scenario));
        };

        //init fee type
        test_scenario::next_tx(scenario, admin);
        {
            fee500bps::init_for_testing(test_scenario::ctx(scenario));
        };


        // init BTCUSDC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let sqrt_price = tools_tests::encode_price_sqrt(1, 1);
            //std::debug::print(&sqrt_price);
            pool_factory::deploy_pool<BTC, USDC, FEE500BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                test_scenario::ctx(scenario),
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
        };
        
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
            let one_btc = 1 * math::pow(10, 9);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<BTC>>(scenario);
            let coins = coin::mint(&mut treasury_cap, one_btc, test_scenario::ctx(scenario));
            transfer::transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

		// mint usdc to player
        test_scenario::next_tx(scenario, admin);
        {
            let one_k_usdc = 1000 * math::pow(10, 9);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<USDC>>(scenario);
            let coins = coin::mint(&mut treasury_cap, one_k_usdc, test_scenario::ctx(scenario));
            transfer::transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        // mint eth to player
        test_scenario::next_tx(scenario, admin);
        {
            let one_k_eth = 1000 * math::pow(10, 9);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<ETH>>(scenario);
            let coins = coin::mint(&mut treasury_cap, one_k_eth, test_scenario::ctx(scenario));
            transfer::transfer(coins, copy player2);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };
	}

    #[test]
    public fun test_deploy_pool() {
        let admin = @0x0;
        let player = @0x1;
		let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        init_pools(admin, player, player2, scenario);

        test_scenario::end(scenario_val);
    }
}