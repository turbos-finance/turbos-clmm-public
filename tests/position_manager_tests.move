// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::position_manager_tests {
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::pool_factory_tests;
    use turbos_clmm::btc::{BTC};
	use turbos_clmm::usdc::{USDC};
    use turbos_clmm::trb::{TRB};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::tools_tests;
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft::{TurbosPositionNFT};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::math_tick;
    use turbos_clmm::math_liquidity;
    use sui::test_utils::{assert_eq};
    use turbos_clmm::fee::{Fee};
    use sui::clock::{Clock};

    public fun init_pool_manager(
		admin: address,
		scenario: &mut Scenario,
	) {
        tools_tests::init_clock(
            admin,
            scenario
        );

        //init pool position manager
        test_scenario::next_tx(scenario, admin);
		{
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };
	}

    #[test]
    //#[expected_failure(abort_code = position_manager::EPositionNotCleared)]
    public fun test_mint() {
        let admin = @0x0;
        let player = @0x1;
		let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        pool_factory_tests::init_pools(admin, player, player2, scenario);

        init_pool_manager(admin, scenario);

        //test BTCUSDC pool, 1BTC = 1USDC
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
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
                &versioned,
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
            assert_eq(coin_a, 1000);
            assert_eq(coin_b, 1000);
            assert_eq(sqrt_price, 18446744073709551616);
            assert_eq(i32::eq(tick_current_index, i32::from(0)), true);
            assert_eq(tick_spacing, 10);
            assert_eq(fee, 500);
            assert_eq(fee_protocol, 0);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 0);
            assert_eq(liquidity, 1000);

            let sqrt_price_a = math_tick::sqrt_price_from_tick_index(min_tick_index);
            let sqrt_price_b = math_tick::sqrt_price_from_tick_index(max_tick_index);
            let (amount_a, amount_b) = math_liquidity::get_amount_for_liquidity(
                sqrt_price,
                sqrt_price_a,
                sqrt_price_b,
                liquidity
            );
            assert_eq(amount_a, 999);
            assert_eq(amount_b, 999);

            //get pool position info
            let (
                liquidity,
                fee_growth_inside_a,
                fee_growth_inside_b,
                tokens_owed_a,
                tokens_owed_b
            ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, player, min_tick_index, max_tick_index);
            assert_eq(liquidity, 1000);
            assert_eq(fee_growth_inside_a, 0);
            assert_eq(fee_growth_inside_b, 0);
            assert_eq(tokens_owed_a, 0);
            assert_eq(tokens_owed_b, 0);


            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //check users coin
        test_scenario::next_tx(scenario, player);
        {
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let amount_btc = coin::value(&btc);
            let amount_usdc = coin::value(&usdc);
            assert_eq(amount_btc, 9000);
            assert_eq(amount_usdc, 9000);

            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_to_sender(scenario, btc);
            test_scenario::return_to_sender(scenario, usdc);
        };

        //test USDCBTC pool, 1USDC = 0.01BTC
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<USDC, TRB, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let trb = test_scenario::take_from_sender<Coin<TRB>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);
            position_manager::mint<USDC, TRB, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(usdc),
                tools_tests::coin_to_vec(trb),
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
		    ) = pool::get_pool_info<USDC, TRB, FEE500BPS>(&pool);
            assert_eq(coin_a, 1000);
            assert_eq(coin_b, 10);
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
            assert_eq(amount_a, 999);
            assert_eq(amount_b, 9);



            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //check users coin
        test_scenario::next_tx(scenario, player);
        {
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let trb = test_scenario::take_from_sender<Coin<TRB>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let amount_trb = coin::value(&trb);
            let amount_usdc = coin::value(&usdc);
            assert_eq(amount_trb, 9990);
            assert_eq(amount_usdc, 8000);

            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_to_sender(scenario, trb);
            test_scenario::return_to_sender(scenario, usdc);
        };

        // increase position liquidity
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);

            position_manager::increase_liquidity(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                &mut nft,
                100,
                100,
                0,
                0,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            let (
                liquidity,
                fee_growth_inside_a,
                fee_growth_inside_b,
                tokens_owed_a,
                tokens_owed_b
            ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, player, min_tick_index, max_tick_index);
            assert_eq(liquidity, 1100);
            assert_eq(fee_growth_inside_a, 0);
            assert_eq(fee_growth_inside_b, 0);
            assert_eq(tokens_owed_a, 0);
            assert_eq(tokens_owed_b, 0);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //check users coin
        test_scenario::next_tx(scenario, player);
        {
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let amount_btc = coin::value(&btc);
            let amount_usdc = coin::value(&usdc);
            assert_eq(amount_btc, 8900);
            assert_eq(amount_usdc, 7900);

            test_scenario::return_to_sender(scenario, btc);
            test_scenario::return_to_sender(scenario, usdc);
        };

        // decrease position liquidity
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);

            position_manager::decrease_liquidity(
                &mut pool,
                &mut positions,
                &mut nft,
                100,
                0,
                0,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            let (
                liquidity,
                fee_growth_inside_a,
                fee_growth_inside_b,
                tokens_owed_a,
                tokens_owed_b
            ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, player, min_tick_index, max_tick_index);
            assert_eq(liquidity, 1000);
            assert_eq(fee_growth_inside_a, 0);
            assert_eq(fee_growth_inside_b, 0);
            assert_eq(tokens_owed_a, 0);
            assert_eq(tokens_owed_b, 0);

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
            assert_eq(coin_a, 1001);
            assert_eq(coin_b, 1001);
            assert_eq(sqrt_price, 18446744073709551616);
            assert_eq(i32::eq(tick_current_index, i32::from(0)), true);
            assert_eq(tick_spacing, 10);
            assert_eq(fee, 500);
            assert_eq(fee_protocol, 0);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 0);
            assert_eq(liquidity, 1000);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //check users coin
        test_scenario::next_tx(scenario, player);
        {
            let amount_btc = tools_tests::get_user_coin_balance<BTC>(scenario);
            let amount_usdc = tools_tests::get_user_coin_balance<USDC>(scenario);
            assert_eq(amount_btc, 8999);
            assert_eq(amount_usdc, 7900 + 99);
        };

        // collect position
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);

            position_manager::collect(
                &mut pool,
                &mut positions,
                &mut nft,
                900,
                90,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            let (
                liquidity,
                fee_growth_inside_a,
                fee_growth_inside_b,
                tokens_owed_a,
                tokens_owed_b
            ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, player, min_tick_index, max_tick_index);
            assert_eq(liquidity, 1000);
            assert_eq(fee_growth_inside_a, 0);
            assert_eq(fee_growth_inside_b, 0);
            assert_eq(tokens_owed_a, 0);
            assert_eq(tokens_owed_b, 0);

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
            assert_eq(coin_a, 1001);
            assert_eq(coin_b, 1001);
            assert_eq(sqrt_price, 18446744073709551616);
            assert_eq(i32::eq(tick_current_index, i32::from(0)), true);
            assert_eq(tick_spacing, 10);
            assert_eq(fee, 500);
            assert_eq(fee_protocol, 0);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 0);
            assert_eq(liquidity, 1000);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //check users coin
        test_scenario::next_tx(scenario, player);
        {
            let amount_btc = tools_tests::get_user_coin_balance<BTC>(scenario);
            let amount_usdc = tools_tests::get_user_coin_balance<USDC>(scenario);
            assert_eq(amount_btc, 8999);
            assert_eq(amount_usdc, 7999);
        };


        // decrease  all
        // test_scenario::next_tx(scenario, player);
        // {
        //     let clock = test_scenario::take_shared<Clock>(scenario);
        //     let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
        //     let positions = test_scenario::take_shared<Positions>(scenario);
        //     let nft_id = tools_tests::get_user_nft_id(object::id(&pool),scenario);
        //     let nft = test_scenario::take_from_sender_by_id<TurbosPositionNFT>(scenario, nft_id);
        //     let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
        //     let min_tick_index = math_tick::get_min_tick(10);
        //     let max_tick_index = math_tick::get_max_tick(10);

        //     position_manager::decrease_liquidity(
        //         &mut pool,
        //         &mut positions,
        //         &mut nft,
        //         1000,
        //         0,
        //         0,
        //         1,
        //         &clock,
        //         test_scenario::ctx(scenario),
        //     );
        //     let (
        //         liquidity,
        //         fee_growth_inside_a,
        //         fee_growth_inside_b,
        //         tokens_owed_a,
        //         tokens_owed_b
        //     ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, player, min_tick_index, max_tick_index);
        //     assert_eq(liquidity, 0);
        //     assert_eq(fee_growth_inside_a, 0);
        //     assert_eq(fee_growth_inside_b, 0);
        //     assert_eq(tokens_owed_a, 0);
        //     assert_eq(tokens_owed_b, 0);

        //     let (
		// 	    coin_a,
		// 	    coin_b,
		// 	    _,
		// 	    _,
		// 	    sqrt_price,
		// 	    tick_current_index,
		// 	    tick_spacing,
		// 	    _,
        //         fee,
        //         fee_protocol,
        //         fee_growth_global_a,
        //         fee_growth_global_b,
        //         liquidity,
		//     ) = pool::get_pool_info<BTC, USDC, FEE500BPS>(&pool);
        //     assert_eq(coin_a, 2);
        //     assert_eq(coin_b, 2);
        //     assert_eq(sqrt_price, 18446744073709551616);
        //     assert_eq(i32::eq(tick_current_index, i32::from(0)), true);
        //     assert_eq(tick_spacing, 10);
        //     assert_eq(fee, 500);
        //     assert_eq(fee_protocol, 0);
        //     assert_eq(fee_growth_global_a, 0);
        //     assert_eq(fee_growth_global_b, 0);
        //     assert_eq(liquidity, 0);

        //     test_scenario::return_immutable(fee_type);
        //     test_scenario::return_to_sender(scenario, nft);
        //     test_scenario::return_shared(pool);
        //     test_scenario::return_shared(positions);
        //     test_scenario::return_shared(clock);
        // };
   
        // collect all
        // test_scenario::next_tx(scenario, player);
        // {
        //     let clock = test_scenario::take_shared<Clock>(scenario);
        //     let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
        //     let positions = test_scenario::take_shared<Positions>(scenario);
        //     let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
        //     let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
        //     let min_tick_index = math_tick::get_min_tick(10);
        //     let max_tick_index = math_tick::get_max_tick(10);

        //     position_manager::collect(
        //         &mut pool,
        //         &mut positions,
        //         &mut nft,
        //         999,
        //         1008,
        //         player,
        //         1,
        //         &clock,
        //         test_scenario::ctx(scenario),
        //     );
        //     let (
        //         liquidity,
        //         fee_growth_inside_a,
        //         fee_growth_inside_b,
        //         tokens_owed_a,
        //         tokens_owed_b
        //     ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, player, min_tick_index, max_tick_index);
        //     assert_eq(liquidity, 0);
        //     assert_eq(fee_growth_inside_a, 0);
        //     assert_eq(fee_growth_inside_b, 0);
        //     assert_eq(tokens_owed_a, 0);
        //     assert_eq(tokens_owed_b, 0);

        //     let (
		// 	    coin_a,
		// 	    coin_b,
		// 	    _,
		// 	    _,
		// 	    sqrt_price,
		// 	    tick_current_index,
		// 	    tick_spacing,
		// 	    _,
        //         fee,
        //         fee_protocol,
        //         fee_growth_global_a,
        //         fee_growth_global_b,
        //         liquidity,
		//     ) = pool::get_pool_info<BTC, USDC, FEE500BPS>(&pool);
        //     assert_eq(coin_a, 2);
        //     assert_eq(coin_b, 2);
        //     assert_eq(sqrt_price, 18446744073709551616);
        //     assert_eq(i32::eq(tick_current_index, i32::from(0)), true);
        //     assert_eq(tick_spacing, 10);
        //     assert_eq(fee, 500);
        //     assert_eq(fee_protocol, 0);
        //     assert_eq(fee_growth_global_a, 0);
        //     assert_eq(fee_growth_global_b, 0);
        //     assert_eq(liquidity, 0);

        //     test_scenario::return_immutable(fee_type);
        //     test_scenario::return_to_sender(scenario, nft);
        //     test_scenario::return_shared(pool);
        //     test_scenario::return_shared(positions);
        //     test_scenario::return_shared(clock);
        // };

        //burn
        // test_scenario::next_tx(scenario, player);
        // {
        //     let positions = test_scenario::take_shared<Positions>(scenario);
        //     let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);

        //     position_manager::burn<BTC, USDC, FEE500BPS>(
        //         &mut positions,
        //         nft,
        //         test_scenario::ctx(scenario),
        //     );
            
        //     test_scenario::return_shared(positions);
        // };
   
        test_scenario::end(scenario_val);
    }
}