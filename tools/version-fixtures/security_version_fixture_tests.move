// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
// Runs only with an explicit test-only private-state constructor in a disposable copy.
#[test_only]
module turbos_clmm::security_version_fixture_tests {
    use std::string;
    use sui::clock::Clock;
    use sui::coin;
    use sui::test_scenario;
    use sui::transfer;
    use turbos_clmm::fee::Fee;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig, AclConfig};
    use turbos_clmm::position_manager::Positions;
    use turbos_clmm::partner::Partner;
    use turbos_clmm::pool_fetcher;
    use turbos_clmm::swap_router;
    use turbos_clmm::security_partner_flash_tests;
    use turbos_clmm::reward_manager;
    use turbos_clmm::security_entrypoint_tests::{Self, A, B, R, S};
    const ADMIN: address = @0xA;

    fun direct(stored: u64, upgrade: bool) {
        let s = security_entrypoint_tests::setup(15);
        test_scenario::next_tx(&mut s, ADMIN);
        let v = pool::security_version_fixture(stored, test_scenario::ctx(&mut s));
        if (upgrade) {
            let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(&s);
            pool_factory::upgrade(&cap, &mut v);
            assert!(pool::version(&v) == 18, 700);
            test_scenario::return_to_sender(&s, cap);
        } else {
            pool::check_version(&v);
            assert!(pool::version(&v) == stored, 701);
        };
        transfer::public_transfer(v, ADMIN);
        test_scenario::end(s);
    }

    fun future_entry(action: u8) {
        let s = security_entrypoint_tests::setup(15);
        let partner_id = if (action >= 23) {
            let (first, _) = security_partner_flash_tests::partners(&mut s);
            std::option::some(first)
        } else std::option::none();
        test_scenario::next_tx(&mut s, ADMIN);
        let v = pool::security_version_fixture(19, test_scenario::ctx(&mut s));
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(&s);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let config = test_scenario::take_shared<PoolConfig>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let vault = test_scenario::take_shared<PoolRewardVault<R>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let fee = test_scenario::take_immutable<Fee<FEE500BPS>>(&s);
        if (action == 0) pool_factory::set_fee_tier_v2(&acl, &mut config, &fee, &v, test_scenario::ctx(&mut s))
        else if (action == 1) pool_factory::set_fee_protocol_v2(&acl, &mut config, 1, &v, test_scenario::ctx(&mut s))
        else if (action == 2) pool_factory::update_pool_fee_protocol_v2(&acl, &mut p, 1, &v, test_scenario::ctx(&mut s))
        else if (action == 3) pool_factory::collect_protocol_fee_v2(&acl, &mut p, 0, 0, ADMIN, &v, test_scenario::ctx(&mut s))
        else if (action == 4) {
            let (a,b) = pool_factory::collect_protocol_fee_with_return_v2(&acl, &mut p, 0, 0, ADMIN, &v, test_scenario::ctx(&mut s));
            coin::burn_for_testing(a); coin::burn_for_testing(b);
        }
        else if (action == 5) pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s))
        else if (action == 6) pool_factory::update_nft_name_v2(&acl, &mut positions, string::utf8(b"x"), &v, test_scenario::ctx(&mut s))
        else if (action == 7) pool_factory::update_nft_description_v2(&acl, &mut positions, string::utf8(b"x"), &v, test_scenario::ctx(&mut s))
        else if (action == 8) pool_factory::update_nft_img_url_v2(&acl, &mut positions, string::utf8(b"x"), &v, test_scenario::ctx(&mut s))
        else if (action == 9) reward_manager::init_reward_v2<A,B,FEE500BPS,S>(&acl, &mut p, 1, ADMIN, &v, test_scenario::ctx(&mut s))
        else if (action == 10) reward_manager::reset_reward_v2<A,B,FEE500BPS,R>(&acl, &mut p, 0, &v, test_scenario::ctx(&mut s))
        else if (action == 11) reward_manager::add_reward_v2(&acl, &mut p, &mut vault, 0, vector[], 0, &clock, &v, test_scenario::ctx(&mut s))
        else if (action == 12) reward_manager::remove_reward_v2(&acl, &mut p, &mut vault, 0, 0, ADMIN, &clock, &v, test_scenario::ctx(&mut s))
        else if (action == 13) reward_manager::update_reward_emissions_v2(&acl, &mut p, 0, 1, &clock, &v, test_scenario::ctx(&mut s))
        else if (action == 14) pool_factory::add_role(&cap, &mut acl, ADMIN, 0, &v)
        else if (action == 15) pool_factory::remove_role(&cap, &mut acl, ADMIN, 0, &v)
        else if (action == 16) pool_factory::remove_member(&cap, &mut acl, ADMIN, &v)
        else if (action == 17) pool_factory::set_roles(&cap, &mut acl, ADMIN, 0, &v)
        else if (action == 18) pool_factory::deploy_pool<A,B,FEE500BPS>(&mut config, &fee, 18446744073709551616, &clock, &v, test_scenario::ctx(&mut s))
        else if (action == 19) pool_factory::deploy_pool_and_mint<A,R,FEE500BPS>(
            &mut config, &fee, 18446744073709551616, &mut positions,
            vector[], vector[], 1000, true, 1000, false, 1, 1, 0, 0,
            ADMIN, 1000, &clock, &v, test_scenario::ctx(&mut s))
        else if (action == 20) {
            let (nft, a, b, _) = pool_factory::deploy_pool_and_mint_with_return_<A,R,FEE500BPS>(
                &mut config, &fee, 18446744073709551616, &mut positions,
                vector[], vector[], 1000, true, 1000, false, 1, 1, 0, 0,
                1000, &clock, &v, test_scenario::ctx(&mut s));
            transfer::public_transfer(nft, ADMIN);
            coin::burn_for_testing(a); coin::burn_for_testing(b);
        }
        else if (action == 21) {
            let _ = pool_fetcher::compute_swap_result(&mut p, true, 1, true,
                4295048016, &clock, &v, test_scenario::ctx(&mut s));
        }
        else if (action == 22) pool_fetcher::fetch_ticks(&mut p, vector[], false, 10, &v)
        else if (action >= 23 && action <= 25) {
            let partner = test_scenario::take_shared_by_id<Partner>(&s, std::option::destroy_some(partner_id));
            let (a, b) = if (action == 23) {
                let a = coin::zero<A>(test_scenario::ctx(&mut s));
                let b = coin::zero<B>(test_scenario::ctx(&mut s));
                swap_router::swap_with_partner(&mut p, &mut partner, a, b,
                    true, 1, 0, 4295048016, true, 1000, &clock, &v, test_scenario::ctx(&mut s))
            } else if (action == 24) {
                let a = coin::zero<A>(test_scenario::ctx(&mut s));
                swap_router::swap_a_b_with_partner(&mut p, &mut partner, a,
                    1, 0, 4295048016, true, 1000, &clock, &v, test_scenario::ctx(&mut s))
            } else {
                let b = coin::zero<B>(test_scenario::ctx(&mut s));
                swap_router::swap_b_a_with_partner(&mut p, &mut partner, b,
                    1, 0, 79226673515401279992447579055, true, 1000, &clock, &v, test_scenario::ctx(&mut s))
            };
            coin::burn_for_testing(a); coin::burn_for_testing(b);
            test_scenario::return_shared(partner);
        }
        else abort 799;
        transfer::public_transfer(v, ADMIN);
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(acl); test_scenario::return_shared(config);
        test_scenario::return_shared(p); test_scenario::return_shared(positions);
        test_scenario::return_shared(vault); test_scenario::return_shared(clock);
        test_scenario::return_immutable(fee); test_scenario::end(s);
    }

    #[test]
    fun current_version_passes() { direct(18, false); }

    #[test]
    fun older_stored_version_passes() { direct(17, false); }

    #[test]
    fun zero_stored_version_passes() { direct(0, false); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_stored_version_rejected() { direct(19, false); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun max_stored_version_rejected() { direct(18446744073709551615, false); }

    #[test]
    fun older_version_upgrades_to_current() { direct(17, true); }

    #[test]
    fun zero_version_upgrades_to_current() { direct(0, true); }

    #[test, expected_failure(abort_code = 22, location = turbos_clmm::pool)]
    fun current_version_cannot_reupgrade() { direct(18, true); }

    #[test, expected_failure(abort_code = 22, location = turbos_clmm::pool)]
    fun future_version_cannot_downgrade() { direct(19, true); }

    #[test, expected_failure(abort_code = 22, location = turbos_clmm::pool)]
    fun max_version_cannot_downgrade() { direct(18446744073709551615, true); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_set_fee_tier() { future_entry(0); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_set_fee_protocol() { future_entry(1); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_update_pool_fee_protocol() { future_entry(2); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_collect_protocol_fee() { future_entry(3); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_collect_protocol_fee_with_return() { future_entry(4); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_toggle_pool_status() { future_entry(5); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_update_nft_name() { future_entry(6); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_update_nft_description() { future_entry(7); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_update_nft_img_url() { future_entry(8); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_init_reward() { future_entry(9); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_reset_reward() { future_entry(10); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_add_reward() { future_entry(11); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_remove_reward() { future_entry(12); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_update_reward_emissions() { future_entry(13); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_add_role() { future_entry(14); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_remove_role() { future_entry(15); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_remove_member() { future_entry(16); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_set_roles() { future_entry(17); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_deploy_pool() { future_entry(18); }

    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_deploy_and_mint() { future_entry(19); }
    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_deploy_and_mint_return() { future_entry(20); }
    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_quote() { future_entry(21); }
    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_fetch_ticks() { future_entry(22); }
    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_generic_partner_router() { future_entry(23); }
    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_a_to_b_partner_router() { future_entry(24); }
    #[test, expected_failure(abort_code = 23, location = turbos_clmm::pool)]
    fun future_version_blocks_b_to_a_partner_router() { future_entry(25); }
}

