// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::swap_router {
	// use std::vector;
    // use sui::vec_map::{Self, VecMap};
    // use sui::transfer;
    // use std::string::{Self, String, utf8};
    // use turbos_clmm::i32::{Self, I32};
    // use turbos_clmm::i128::{Self, I128};
    // use sui::table::{Self, Table};
    // use turbos_clmm::string_tools;
    // use sui::object::{Self, UID, ID};
    // use sui::tx_context::{Self, TxContext};
    // use sui::dynamic_object_field as dof;
    // use turbos_clmm::pool::{Self, Pool};
    // use turbos_clmm::position_manager::{Self, Positions};
	// use sui::transfer::transfer;
	// use sui::coin::{Self, Coin};
	// use sui::balance::{Self, Balance, Supply};
	// use sui::pay;
    // use turbos_clmm::full_math_u128;
    // use turbos_clmm::math_liquidity;
    // use turbos_clmm::math_tick;
    
    // public entry fun exact_input_single<CoinTypeA, CoinTypeB, FeeType>(
	// 	pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
	// 	positions: &mut Positions,
	// 	coins_a: vector<Coin<CoinTypeA>>, 
	// 	fee: u32,
	// 	amount_in: u128,
    //     amount_out_min: u128,
    //     sqrt_price_limit: u128,
    //     recipient: address,
    //     deadline: u128,
	// 	ctx: &mut TxContext
    // ) {
	// 	transfer(position_manager::merge_coin<CoinTypeA>(coins_a), recipient);
    // }

    // public entry fun exact_input<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
	// 	pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
    //     pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
	// 	positions: &mut Positions,
	// 	coins_a: vector<Coin<CoinTypeA>>, 
	// 	fee: u32,
	// 	amount_in: u128,
    //     amount_out_min: u128,
    //     sqrt_price_limit: u128,
    //     recipient: address,
    //     _deadline: u128,
	// 	ctx: &mut TxContext
    // ) {
	// 	pool::swap<CoinTypeA, CoinTypeB, FeeTypeA>(
    //         pool_a,
    //         recipient,
    //         true,
    //         i128::from(amount_in),
    //         sqrt_price_limit,
    //         ctx,
    //     );
    //     pool::swap<CoinTypeB, CoinTypeC, FeeTypeB>(
    //         pool_b,
    //         recipient,
    //         true,
    //         i128::from(amount_in),
    //         sqrt_price_limit,
    //         ctx,
    //     );
    //     transfer(position_manager::merge_coin<CoinTypeA>(coins_a), recipient);
    // }
}