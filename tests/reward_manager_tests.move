// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::reward_manager_tests {
    use std::vector;
    use sui::object::{Self};
    use sui::coin::{Coin};
    use sui::balance::{Self};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::pool_factory_tests;
    use turbos_clmm::btc::{BTC};
	use turbos_clmm::usdc::{USDC};
    use turbos_clmm::eth::{ETH};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault};
    use turbos_clmm::reward_manager::{Self, RewardManagerAdminCap};
    use sui::test_utils::{assert_eq};
    use sui::clock::{Self, Clock};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::math_tick;
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::tools_tests;
    use turbos_clmm::position_nft::{TurbosPositionNFT};

    public fun init_reward_manager(
		player: address,
		scenario: &mut Scenario,
	) {
        // init clock
        test_scenario::next_tx(scenario, player);
        {
            clock::create_for_testing(test_scenario::ctx(scenario));
        };

        //init reward manager
        test_scenario::next_tx(scenario, player);
		{
            reward_manager::init_for_testing(test_scenario::ctx(scenario));
        };

	}

    #[test]
    //#[expected_failure(abort_code = pool::EInvalidRewardManager)]
    public fun test_reward_config() {
        let admin = @0x0;
        let player = @0x1;
		let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        pool_factory_tests::init_pools(admin, player, player2, scenario);

        tools_tests::init_tests_coin(
            admin,
            player,
            player2,
            100000,
            scenario
        );

        //init pool position manager
        test_scenario::next_tx(scenario, player);
		{
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };

        //test BTCUSDC pool, 1BTC = 1USDC
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);
            position_manager::mint<BTC, USDC, FEE500BPS>(
                &mut pool,
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
                test_scenario::ctx(scenario),
            );

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
        };

        init_reward_manager(player, scenario);

        //test init_reward
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let manager = test_scenario::take_from_sender<RewardManagerAdminCap>(scenario);
            reward_manager::init_reward<BTC, USDC, FEE500BPS, ETH>(
                &manager,
                &mut pool,
                0, // index 0, reawrd ETH
                player,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_to_sender(scenario, manager);
            test_scenario::return_shared(pool);
        };

        //assert vault
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let reward_vault = test_scenario::take_shared<PoolRewardVault<ETH>>(scenario);
            let (vault, emissions_per_second, growth_global, manager) = pool::get_reward_info<BTC, USDC, FEE500BPS>(&pool, 0);
            assert_eq(vault, object::id_address(&reward_vault));
            assert_eq(balance::value(pool::get_reward_vault(&reward_vault)), 0);
            assert_eq(emissions_per_second, 0);
            assert_eq(growth_global, 0);
            assert_eq(manager, player);

            test_scenario::return_shared(reward_vault);
            test_scenario::return_shared(pool);
        };

        //test update_reward_emissions
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let reward_vault = test_scenario::take_shared<PoolRewardVault<ETH>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            reward_manager::update_reward_emissions<BTC, USDC, FEE500BPS>(
                &mut pool,
                0, // index 0, reawrd ETH
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            let (vault, emissions_per_second, growth_global, manager) = pool::get_reward_info<BTC, USDC, FEE500BPS>(&pool, 0);
            assert_eq(vault, object::id_address(&reward_vault));
            assert_eq(balance::value(pool::get_reward_vault(&reward_vault)), 0);
            assert_eq(emissions_per_second >> 64, 100);
            assert_eq(growth_global, 0);
            assert_eq(manager, player);

            test_scenario::return_shared(clock);
            test_scenario::return_shared(reward_vault);
            test_scenario::return_shared(pool);
        };

        //test will fail if not manager on update_reward_emissions
        // test_scenario::next_tx(scenario, player2);
        // {
        //     let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
        //     reward_manager::update_reward_emissions<BTC, USDC, FEE500BPS>(
        //         &mut pool,
        //         0, // index 0, reawrd ETH
        //         100,
        //         test_scenario::ctx(scenario),
        //     );
        //     test_scenario::return_shared(pool);
        // };

        //add reward
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let reward_vault = test_scenario::take_shared<PoolRewardVault<ETH>>(scenario);
            let eth = test_scenario::take_from_sender<Coin<ETH>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            reward_manager::add_reward<BTC, USDC, FEE500BPS, ETH>(
                &mut pool,
                &mut reward_vault,
                0,
                tools_tests::coin_to_vec(eth),
                20000,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(balance::value(pool::get_reward_vault(&reward_vault)), 20000);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(reward_vault);
            test_scenario::return_shared(pool);
        };

        //next reawrd
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, 10000); //10s
            let infos = pool::next_pool_reward_infos_for_testing(&mut pool, &clock);
            let growth_global = *vector::borrow(&infos, 0);
            assert_eq(growth_global >> 64, 1);// per liquidity

            clock::increment_for_testing(&mut clock, 100000); //100s
            infos = pool::next_pool_reward_infos_for_testing(&mut pool, &clock);
            growth_global = *vector::borrow(&infos, 0);
            assert_eq(growth_global >> 64, 11);

            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };

        //remove reward
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let reward_vault = test_scenario::take_shared<PoolRewardVault<ETH>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            reward_manager::remove_reward<BTC, USDC, FEE500BPS, ETH>(
                &mut pool,
                &mut reward_vault,
                0,
                10000,
                player,
                &clock,
                test_scenario::ctx(scenario),
            );

            assert_eq(balance::value(pool::get_reward_vault(&reward_vault)), 10000);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(reward_vault);
            test_scenario::return_shared(pool);
        };

        //collect reward
        let eth_amount_before;
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let reward_vault = test_scenario::take_shared<PoolRewardVault<ETH>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            eth_amount_before =  tools_tests::get_user_coin_balance<ETH>(scenario);
            
            position_manager::collect_reward<BTC, USDC, FEE500BPS, ETH>(
                &mut pool,
                &mut positions,
                &mut nft,
                &mut reward_vault,
                0,
                10000,
                player,
                200000,
                &clock,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(positions);
            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(reward_vault);
            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(scenario, player);
        {
            let eth_amount_after =  tools_tests::get_user_coin_balance<ETH>(scenario);
            let eth_amount_diff = eth_amount_after - eth_amount_before;
            assert_eq(eth_amount_diff, 10000);
        };

        test_scenario::end(scenario_val);
    }
}