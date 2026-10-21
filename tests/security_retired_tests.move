// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_retired_tests {
    use std::string;
    use sui::clock::Clock;
    use sui::coin;
    use sui::test_scenario;
    use turbos_clmm::fee::Fee;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::pool::{Pool, PoolRewardVault, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::position_manager::Positions;
    use turbos_clmm::reward_manager::{Self, RewardManagerAdminCap};
    use turbos_clmm::security_entrypoint_tests::{Self, A, B, R};
    const ADMIN: address = @0xA;
    fun factory(action: u8) {
        let s = security_entrypoint_tests::setup(15);
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let config = test_scenario::take_shared<PoolConfig>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let fee = test_scenario::take_immutable<Fee<FEE500BPS>>(&s);
        if (action == 0) pool_factory::set_fee_tier(&cap, &mut config, &fee, &v)
        else if (action == 1) pool_factory::set_fee_protocol(&cap, &mut config, 1, &v)
        else if (action == 2) pool_factory::update_pool_fee_protocol(&cap, &mut p, 1, &v, test_scenario::ctx(&mut s))
        else if (action == 3) pool_factory::collect_protocol_fee(&cap, &mut p, 0, 0, ADMIN, &v, test_scenario::ctx(&mut s))
        else if (action == 4) {
            let (a, b) = pool_factory::collect_protocol_fee_with_return_(&cap, &mut p, 0, 0, ADMIN, &v, test_scenario::ctx(&mut s));
            coin::burn_for_testing(a); coin::burn_for_testing(b);
        }
        else if (action == 5) pool_factory::toggle_pool_status(&cap, &mut p, &v, test_scenario::ctx(&mut s))
        else if (action == 6) pool_factory::update_nft_name(&cap, &mut positions, string::utf8(b"x"), &v, test_scenario::ctx(&mut s))
        else if (action == 7) pool_factory::update_nft_description(&cap, &mut positions, string::utf8(b"x"), &v, test_scenario::ctx(&mut s))
        else if (action == 8) pool_factory::update_nft_img_url(&cap, &mut positions, string::utf8(b"x"), &v, test_scenario::ctx(&mut s))
        else if (action == 9) pool_factory::migrate_position(&cap, &mut p, &mut positions, vector[], ADMIN, &v, test_scenario::ctx(&mut s))
        else if (action == 10) pool_factory::decrease_liquidity_admin(&cap, &mut p, &mut positions, ADMIN, 10, true, 10, false, ADMIN, &clock, &v, test_scenario::ctx(&mut s))
        else if (action == 11) pool_factory::modify_tick_reward(&cap, &mut p, 10, true, &clock, &v, test_scenario::ctx(&mut s))
        else if (action == 12) pool_factory::modify_tick(&cap, &mut p, 10, true, &v)
        else if (action == 13) pool_factory::modify_reward(&cap, &mut p, &mut positions, 10, true, 10, false, vector[], vector[], &v, test_scenario::ctx(&mut s))
        else if (action == 14) pool_factory::fake_swap(&cap, &mut p, ADMIN, true, 1, true, 4295048016, &clock, &v, test_scenario::ctx(&mut s))
        else abort 600;
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(p); test_scenario::return_shared(config);
        test_scenario::return_shared(positions); test_scenario::return_shared(clock);
        test_scenario::return_shared(v); test_scenario::return_immutable(fee);
        test_scenario::end(s);
    }
    fun reward(action: u8) {
        let s = security_entrypoint_tests::setup(15);
        test_scenario::next_tx(&mut s, ADMIN);
        reward_manager::init_for_testing(test_scenario::ctx(&mut s));
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<RewardManagerAdminCap>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let vault = test_scenario::take_shared<PoolRewardVault<R>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        if (action == 0) reward_manager::init_reward<A, B, FEE500BPS, R>(&cap, &mut p, 0, ADMIN, &v, test_scenario::ctx(&mut s))
        else if (action == 1) reward_manager::reset_reward<A, B, FEE500BPS, R>(&cap, &mut p, 0, &v, test_scenario::ctx(&mut s))
        else if (action == 2) reward_manager::update_reward_manager(&cap, &mut p, 0, ADMIN, &v, test_scenario::ctx(&mut s))
        else if (action == 3) reward_manager::add_reward(&mut p, &mut vault, 0, vector[], 0, &clock, &v, test_scenario::ctx(&mut s))
        else if (action == 4) reward_manager::remove_reward(&mut p, &mut vault, 0, 0, ADMIN, &clock, &v, test_scenario::ctx(&mut s))
        else if (action == 5) reward_manager::update_reward_emissions(&mut p, 0, 1, &clock, &v, test_scenario::ctx(&mut s))
        else abort 601;
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(p); test_scenario::return_shared(vault);
        test_scenario::return_shared(clock); test_scenario::return_shared(v);
        test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_set_fee_tier_aborts_in_defining_module() { factory(0); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_set_fee_protocol_aborts_in_defining_module() { factory(1); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_update_pool_fee_protocol_aborts_in_defining_module() { factory(2); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_collect_protocol_fee_aborts_in_defining_module() { factory(3); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_collect_protocol_fee_with_return_aborts_in_defining_module() { factory(4); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_toggle_pool_status_aborts_in_defining_module() { factory(5); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_update_nft_name_aborts_in_defining_module() { factory(6); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_update_nft_description_aborts_in_defining_module() { factory(7); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_update_nft_img_url_aborts_in_defining_module() { factory(8); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_migrate_position_aborts_in_defining_module() { factory(9); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_decrease_liquidity_admin_aborts_in_defining_module() { factory(10); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_modify_tick_reward_aborts_in_defining_module() { factory(11); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_modify_tick_aborts_in_defining_module() { factory(12); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_modify_reward_aborts_in_defining_module() { factory(13); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::pool_factory)]
    fun retired_fake_swap_aborts_in_defining_module() { factory(14); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::reward_manager)]
    fun retired_init_reward_aborts_in_defining_module() { reward(0); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::reward_manager)]
    fun retired_reset_reward_aborts_in_defining_module() { reward(1); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::reward_manager)]
    fun retired_update_reward_manager_aborts_in_defining_module() { reward(2); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::reward_manager)]
    fun retired_add_reward_aborts_in_defining_module() { reward(3); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::reward_manager)]
    fun retired_remove_reward_aborts_in_defining_module() { reward(4); }

    #[test, expected_failure(abort_code = 0, location = turbos_clmm::reward_manager)]
    fun retired_update_reward_emissions_aborts_in_defining_module() { reward(5); }
}

