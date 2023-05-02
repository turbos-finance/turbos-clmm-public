// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::pool_factory_tests {
	use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::btc::{BTC};
	use turbos_clmm::usdc::{USDC};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::tools_tests;
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::math_sqrt_price::{Self};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::math_tick;
    use turbos_clmm::position_manager::{Self,Positions};
    use turbos_clmm::pool::{Versioned};
    use sui::coin::{Coin};
    use std::string::{Self};
    use sui::clock::{Clock};

	public fun init_pools(
		admin: address,
		player: address,
		player2: address, 
		scenario: &mut Scenario,
	) {
        tools_tests::init_tests_coin(
            admin,
            player,
            player2,
            10000,
            scenario
        );

        tools_tests::init_pool_factory(
            admin,
            scenario
        );

        tools_tests::init_fee_type(
            admin,
            scenario
        );

        tools_tests::init_clock(
            admin,
            scenario
        );

        //init BTCUSDC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            //price=1 1btc = 1usdc
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<BTC, USDC, FEE500BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        // init USDCBTC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            //price=0.01 1usdc = 0.01BTC
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 100);
            pool_factory::deploy_pool<USDC, BTC, FEE500BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };
	}

    #[test]
    #[expected_failure(abort_code = pool_factory::ERepeatedType)]
    public fun repeated_type_on_deploy_pool() {
        let admin = @0x0;
        let player = @0x1;
		let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        tools_tests::init_tests_coin(
            admin,
            player,
            player2,
            10000,
            scenario
        );

        tools_tests::init_pool_factory(
            admin,
            scenario
        );

        tools_tests::init_fee_type(
            admin,
            scenario
        );


        tools_tests::init_clock(
            admin,
            scenario
        );
        //init BTCBTC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            //price=1 1btc = 1usdc
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<BTC, BTC, FEE500BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };
        test_scenario::end(scenario_val);
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

    #[test]
    public fun test_deploy_pool_and_mint() {
        let admin = @0x0;
        let player = @0x1;
		let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        tools_tests::init_tests_coin(
            admin,
            player,
            player2,
            100000,
            scenario
        );

        tools_tests::init_pool_factory(
            player,
            scenario
        );

        tools_tests::init_fee_type(
            player,
            scenario
        );

        //init pool position manager
        test_scenario::next_tx(scenario, player);
		{
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };
        
        tools_tests::init_clock(
            player,
            scenario
        );

        // init USDCBTC pool
        test_scenario::next_tx(scenario, player);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            //price=0.01 1usdc = 0.01BTC
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 100);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            pool_factory::deploy_pool_and_mint<BTC, USDC, FEE500BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                1000,
                1000,
                0,
                0,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_update_nft_metadata() {
        let admin = @0x0;
        let player = @0x1;
		let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        init_pools(admin, player, player2, scenario);

        //init pool position manager
        test_scenario::next_tx(scenario, admin);
		{
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };

        //init BTCBTC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            pool_factory::update_nft_name(
                &admin_cap,
                &mut positions,
                string::utf8(b"name"),
                &versioned,
                test_scenario::ctx(scenario),
            );

            pool_factory::update_nft_description(
                &admin_cap,
                &mut positions,
                string::utf8(b"description"),
                &versioned,
                test_scenario::ctx(scenario),
            );

            pool_factory::update_nft_img_url(
                &admin_cap,
                &mut positions,
                string::utf8(b"imgurl"),
                &versioned,
                test_scenario::ctx(scenario),
            );
            //std::debug::print(&positions);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }
}