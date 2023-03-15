// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::swap_router_tests {

	use sui::coin::{Coin};
    use sui::test_scenario::{Self};
    use turbos_clmm::pool_factory_tests;
    use turbos_token::btc::{BTC};
	use turbos_token::usdc::{USDC};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::pool::{Pool};
    use turbos_clmm::tools_tests;
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::math_tick;
    use turbos_clmm::fee::{Self, Fee};
	use turbos_clmm::swap_router;
	use turbos_clmm::position_manager_tests;

	const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;

	#[test]
	public fun test_swap() {
		let admin = @0x0;
        let player = @0x1;
		let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

		position_manager_tests::init_pool_manager(admin, scenario);

        pool_factory_tests::init_pools(admin, player, player2, scenario);

		//add liquidity
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
                1000,
                1000,
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

		// swap btc to usdc
		test_scenario::next_tx(scenario, player);
        {
			let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
			let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);

			swap_router::swap_a_b(
				&mut pool,
				tools_tests::coin_to_vec(btc),
				100,
				1,
				MIN_SQRT_PRICE_X64 + 1,
				player,
				1,
				test_scenario::ctx(scenario),
			);

			test_scenario::return_shared(pool);
		};

		test_scenario::end(scenario_val);
	}
}