// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::reward_manager {
    use sui::object::{Self, UID};
    use sui::transfer;
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Coin};

    struct RewardManagerAdminCap has key, store { id: UID }

    fun init(ctx: &mut TxContext) {
        init_(ctx);
    }

    fun init_(ctx: &mut TxContext) {
        transfer::transfer(RewardManagerAdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    public entry fun init_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        _: &RewardManagerAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        manager: address,
        ctx: &mut TxContext
    ) {
        let vault = pool::init_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
            pool,
            reward_index,
            manager,
            ctx,
        );
        transfer::public_share_object(vault);
    }

    public entry fun add_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        reward_index: u64,
        coins: vector<Coin<RewardCoin>>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        pool::add_reward(
            pool,
            vault,
            reward_index,
            pool::merge_coin<RewardCoin>(coins),
            amount,
            ctx,
        );
    }

    public entry fun remove_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        reward_index: u64,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        pool::remove_reward(
            pool,
            vault,
            reward_index,
            amount,
            recipient,
            ctx,
        );
    }

    // update reward emissions per second
    // will check manager address
    public entry fun update_reward_emissions<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        emissions_per_second: u128,
        ctx: &mut TxContext
    ) {
        pool::update_reward_emissions(
            pool,
            reward_index,
            emissions_per_second,
            ctx,
        );
    }
}