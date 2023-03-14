// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::position_manager_tests {
    use sui::coin::{Coin};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::pool_factory_tests;
    use turbos_token::btc::{BTC};
	use turbos_token::usdc::{USDC};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::pool::{Self, Pool};
    use turbos_clmm::tools_tests;
    use turbos_clmm::position_manager::{Self, Positions, TurbosPositionNFT};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::math_tick;
    use turbos_clmm::math_liquidity;
    use sui::test_utils::{assert_eq};
    use turbos_clmm::fee::{Self, Fee};

    public fun init_pool_manager(
		admin: address,
		scenario: &mut Scenario,
	) {
        //init pool position manager
        test_scenario::next_tx(scenario, admin);
		{
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };
	}

    #[test]
    public fun test_mint() {
        let admin = @0x0;
        let player = @0x1;
		let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        pool_factory_tests::init_pools(admin, player, player2, scenario);

        init_pool_manager(admin, scenario);

        //test BTCUSDC pool, 1BTC = 100USDC
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let fee = fee::get_fee<FEE500BPS>(&fee_type);
            let min_tick_index = math_tick::get_min_tick(fee);
            let max_tick_index = math_tick::get_max_tick(fee);
            position_manager::mint<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                10000,
                10000,
                0,
                0,
                player,
                1,
                test_scenario::ctx(scenario),
            );

            assert_eq(position_manager::get_nft_minted(&positions), 1);
            let (
			    coin_a,
			    coin_b,
			    _,
			    _,
			    sqrt_price,
			    tick_current_index,
			    tick_spacing,
			    _,
                fee,
                fee_protocol,
                fee_growth_global_a,
                fee_growth_global_b,
                liquidity,
		    ) = pool::get_pool_info<BTC, USDC, FEE500BPS>(&pool);
            assert_eq(coin_a, 100);
            assert_eq(coin_b, 10000);
            assert_eq(sqrt_price, 184467440737095516160);
            assert_eq(i32::eq(tick_current_index, i32::from(46054)), true);
            assert_eq(tick_spacing, 10);
            assert_eq(fee, 500);
            assert_eq(fee_protocol, 0);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 0);

            let sqrt_price_a = math_tick::sqrt_price_from_tick_index(min_tick_index);
            let sqrt_price_b = math_tick::sqrt_price_from_tick_index(max_tick_index);
            let (amount_a, amount_b) = math_liquidity::get_amount_for_liquidity(
                sqrt_price,
                sqrt_price_a,
                sqrt_price_b,
                liquidity
            );
            assert_eq(amount_a, 99);
            assert_eq(amount_b, 9999);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
        };

        //test USDCBTC pool, 1USDC = 0.01BTC
         test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<USDC, BTC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let fee = fee::get_fee<FEE500BPS>(&fee_type);
            let min_tick_index = math_tick::get_min_tick(fee);
            let max_tick_index = math_tick::get_max_tick(fee);
            position_manager::mint<USDC, BTC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(usdc),
                tools_tests::coin_to_vec(btc),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                10000,
                10000,
                0,
                0,
                player,
                1,
                test_scenario::ctx(scenario),
            );

            //get last nft
            let nft = test_scenario::take_from_sender<TurbosPositionNFT<BTC, USDC, FEE500BPS>>(scenario);
            test_scenario::return_to_sender(scenario, nft);

            assert_eq(position_manager::get_nft_minted(&positions), 2);
            let (
			    coin_a,
			    coin_b,
			    _,
			    _,
			    sqrt_price,
			    tick_current_index,
			    tick_spacing,
			    _,
                fee,
                fee_protocol,
                fee_growth_global_a,
                fee_growth_global_b,
                liquidity,
		    ) = pool::get_pool_info<USDC, BTC, FEE500BPS>(&pool);
            assert_eq(coin_a, 10000);
            assert_eq(coin_b, 100);
            assert_eq(sqrt_price, 1844674407370955161);
            assert_eq(i32::eq(tick_current_index, i32::neg_from(46055)), true);
            assert_eq(tick_spacing, 10);
            assert_eq(fee, 500);
            assert_eq(fee_protocol, 0);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 0);

            let sqrt_price_a = math_tick::sqrt_price_from_tick_index(min_tick_index);
            let sqrt_price_b = math_tick::sqrt_price_from_tick_index(max_tick_index);
            let (amount_a, amount_b) = math_liquidity::get_amount_for_liquidity(
                sqrt_price,
                sqrt_price_a,
                sqrt_price_b,
                liquidity
            );
            assert_eq(amount_a, 9999);
            assert_eq(amount_b, 99);



            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
        };

        test_scenario::end(scenario_val);
    }
}