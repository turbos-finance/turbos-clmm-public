// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::fetch_ticks_simple_tests {
    use sui::test_scenario::{Self};
    use turbos_clmm::pool_factory_tests;
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_fetcher;
    use turbos_clmm::position_manager_tests;
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::math_tick;
    use sui::coin::{Coin};
    use sui::clock::{Clock};
    use turbos_clmm::tools_tests;
    use std::vector;

    const MAX_TICK_INDEX: u32 = 443636;

    #[test]
    public fun test_fetch_ticks_empty_start_array() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize pool manager and pools
        position_manager_tests::init_pool_manager(admin, scenario);
        pool_factory_tests::init_pools(admin, player, player2, scenario);

        // Add some liquidity to create initialized ticks
        test_scenario::next_tx(scenario, admin);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            
            // Create some liquidity positions to initialize ticks
            // Use tick spacing = 60 for FEE3000BPS
            let tick_lower = i32::neg_from(600);  // -600 (aligned to 60)
            let tick_upper = i32::from(600);      // 600 (aligned to 60)
            
            // Add liquidity which will initialize these ticks
            pool::mint_for_testing<BTC, USDC, FEE3000BPS>(
                &mut pool,
                admin,
                tick_lower,
                tick_upper,
                1000000, // liquidity delta
                &clock,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
        };
        
        // Add more liquidity at different tick ranges  
        test_scenario::next_tx(scenario, admin);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            
            // Add liquidity at more distant ticks
            let tick_lower = i32::neg_from(1800);  // -1800 (aligned to 60)
            let tick_upper = i32::neg_from(1200);  // -1200 (aligned to 60)
            
            pool::mint_for_testing<BTC, USDC, FEE3000BPS>(
                &mut pool,
                admin,
                tick_lower,
                tick_upper,
                500000, // smaller liquidity
                &clock,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
        };

        // Now test fetch_ticks with some initialized ticks
        test_scenario::next_tx(scenario, admin);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test with empty start array (exactly the case that was failing)
            // This reproduces the exact condition from the error report
            let empty_start = vector::empty<u32>();
            
            // This should NOT crash with EInvildTick error after applying the fix:
            // start_index = i32::mul(tick_spacing, i32::div(start_index, tick_spacing));
            pool_fetcher::fetch_ticks<BTC, USDC, FEE3000BPS>(
                &mut pool,
                empty_start,
                false, // start_index_is_neg (not used when array is empty)
                980,   // limit (same as in original error)
                &versioned
            );
            
            // If we reach here, the test passed - no EInvildTick error occurred
            // The function emits an event with the results instead of returning them

            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fetch_ticks_max_boundary() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);
        pool_factory_tests::init_pools(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, admin);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test with MAX_TICK_INDEX
            let start_array = vector::empty<u32>();
            vector::push_back(&mut start_array, MAX_TICK_INDEX);
            
            // Test positive boundary
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                start_array,
                false, // start_index_is_neg = false (positive)
                10,
                &versioned
            );
            
            // Test negative boundary  
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                start_array,
                true, // start_index_is_neg = true (negative)
                10,
                &versioned
            );

            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario_val);
    }
}