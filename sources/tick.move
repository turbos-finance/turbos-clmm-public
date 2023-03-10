// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::tick {
	//use turbos_clmm::math_tick;
    use sui::transfer;
    use std::string::{Self, String};
	use turbos_clmm::i32::{Self, I32};
	use turbos_clmm::i128::{Self, I128};
	use sui::table::{Self, Table};
    use turbos_clmm::string_tools;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};

    const TickNotFound: u64 = 0;

	const MAX_U128: u128 = 0xffffffffffffffffffffffffffffffff;
	const MAX_TICK_INDEX: u32 = 443636;

	struct Tick has copy, drop, store {
        liquidity_gross: u128,
        liquidity_net: I128,
        fee_growth_outside_a_64: u128,
		fee_growth_outside_b_64: u128,
        initialized: bool,
    }

    public fun get_initialize_tick(): Tick {
        Tick {
			liquidity_gross: 0,
        	liquidity_net: i128::zero(),
        	fee_growth_outside_a_64: 0,
			fee_growth_outside_b_64: 0,
        	initialized: false,
		}
    }

	public fun max_liquidity_per_tick(tick_spacing: u32): u128 {
		let num_ticks = MAX_TICK_INDEX * 2 / tick_spacing + 1;
		let liquidity = MAX_U128 / (num_ticks as u128);

        liquidity
    }

    // public fun get_tick_index_string(index: I32): String {
    //     let str = string_tools::u64_to_string((i32::as_u32(index) as u64));
    //     if (i32::is_neg(index)) {
    //         string::append(&mut string::utf8(b"-"), str)
    //     };

    //     str
    // }

	// public fun get_tick(pool: &Pool, index: I32): &Tick {
    //     ///let key = get_tick_index_string(index);
    //     assert!(dof::exists_(&pool.id, index), TickNotFound);
    //     let tick = dof::borrow(&pool.id, index);

    //     tick
	// }

	/// @return fee_growth_inside_a_64
    /// @return fee_growth_inside_b_64
	public fun  get_fee_growth_inside(
        tick_current_index: I32,
		tick_lower: &Tick,
        tick_lower_index: I32,
        tick_upper: &Tick,
        tick_upper_index: I32,
        fee_growth_global_a_64: u128,
        fee_growth_global_b_64: u128,
    ): (u128, u128) {
        // calculate fee growth below
        let fee_growth_below_a_64;
        let fee_growth_below_b_64;
        if (i32::gte(tick_current_index, tick_lower_index)) {
            fee_growth_below_a_64 = tick_lower.fee_growth_outside_a_64;
            fee_growth_below_b_64 = tick_lower.fee_growth_outside_b_64;
        } else {
            fee_growth_below_a_64 = fee_growth_global_a_64 - tick_lower.fee_growth_outside_a_64;
            fee_growth_below_b_64 = fee_growth_global_b_64 - tick_lower.fee_growth_outside_b_64;
        };

        // calculate fee growth above
        let fee_growth_above_a_64;
        let fee_growth_above_b_64;
        if (i32::lt(tick_current_index, tick_upper_index)) {
            fee_growth_above_a_64 = tick_upper.fee_growth_outside_a_64;
            fee_growth_above_b_64 = tick_upper.fee_growth_outside_b_64;
        } else {
            fee_growth_above_a_64 = fee_growth_global_a_64 - tick_upper.fee_growth_outside_a_64;
            fee_growth_above_b_64 = fee_growth_global_b_64 - tick_upper.fee_growth_outside_b_64;
        };

        let fee_growth_inside_a_64 = fee_growth_global_a_64 - fee_growth_below_a_64 - fee_growth_above_a_64;
        let fee_growth_inside_b_64 = fee_growth_global_b_64 - fee_growth_below_b_64 - fee_growth_above_b_64;

		(fee_growth_inside_a_64, fee_growth_inside_b_64)
    }

	#[test]
    fun test_max_liquidity_per_tick_one() {
        let l = max_liquidity_per_tick(1);
		std::debug::print(&l);
        //assert!(i32::eq(r, i32::neg_from(MAX_TICK_INDEX)), 0);
    }

	//returns all for two uninitialized ticks if tick is inside
    // #[test]
	// fun test_get_fee_growth_inside_0() {
    //     use sui::test_scenario::{Self, Scenario};
    //     let admin = @0xBABE;
    //     let scenario_val = test_scenario::begin(admin);
    //     let scenario = &mut scenario_val;


    //     test_scenario::next_tx(scenario, admin);
    //     {
    //           let ticks = table::new<I32, Tick>(test_scenario::ctx(scenario));
    //     table::add(&mut ticks, i32::neg_from(2), get_initialize_tick());
    //     table::add(&mut ticks, i32::from(2), get_initialize_tick());
    //     let (fee_growth_inside_a_64, fee_growth_inside_b_64) = get_fee_growth_inside(
	// 		&ticks,
	// 		i32::neg_from(2), 
	// 		i32::from(2), 
	// 		i32::zero(), 
	// 		15, 
	// 		15);
	// 	assert!(fee_growth_inside_a_64 == 15, 0);
	// 	assert!(fee_growth_inside_b_64 == 15, 0);

    //     };
      
    //     test_scenario::end(scenario_val);
    // }
}