// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_entrypoint_tests {
    use std::string;
    use sui::balance;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::fee::Fee;
    use turbos_clmm::fee500bps::{Self, FEE500BPS};
    use turbos_clmm::fee1000bps::{Self, FEE1000BPS};
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig, AclConfig};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::reward_manager;

    const ADMIN: address = @0xA;
    const OPERATOR: address = @0xB;
    const RECIPIENT: address = @0xC;
    struct A has drop {}
    struct B has drop {}
    struct R has drop {}
    struct S has drop {}

    // Minimal fixture: no TreasuryCaps, unrelated currencies or production edits.
    // A real shared pool and reward vault are created via production entry points.
    public fun setup(roles: u128): Scenario {
        let s = test_scenario::begin(ADMIN);
        pool_factory::init_for_testing(test_scenario::ctx(&mut s));
        pool::init_for_testing(test_scenario::ctx(&mut s));
        position_manager::init_for_testing(test_scenario::ctx(&mut s));
        fee500bps::init_for_testing(test_scenario::ctx(&mut s));
        fee1000bps::init_for_testing(test_scenario::ctx(&mut s));
        let clock = clock::create_for_testing(test_scenario::ctx(&mut s));
        clock::share_for_testing(clock);
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(&s);
        pool_factory::init_acl_config(&cap, test_scenario::ctx(&mut s));
        test_scenario::return_to_sender(&s, cap);
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(&s);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let config = test_scenario::take_shared<PoolConfig>(&s);
        let fee = test_scenario::take_immutable<Fee<FEE500BPS>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        pool_factory::set_roles(&cap, &mut acl, OPERATOR, roles, &v);
        pool_factory::set_fee_tier_v2(&acl, &mut config, &fee, &v, test_scenario::ctx(&mut s));
        pool_factory::deploy_pool<A, B, FEE500BPS>(
            &mut config, &fee, 18446744073709551616, &clock, &v,
            test_scenario::ctx(&mut s),
        );
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(acl);
        test_scenario::return_shared(v);
        test_scenario::return_shared(config);
        test_scenario::return_immutable(fee);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(&mut s, ADMIN);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        reward_manager::init_reward_v2<A, B, FEE500BPS, R>(
            &acl, &mut p, 0, ADMIN, &v, test_scenario::ctx(&mut s),
        );
        test_scenario::return_shared(acl);
        test_scenario::return_shared(p);
        test_scenario::return_shared(v);
        test_scenario::next_tx(&mut s, ADMIN);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let vault = test_scenario::take_shared<PoolRewardVault<R>>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let funds = coin::mint_for_testing<R>(100, test_scenario::ctx(&mut s));
        reward_manager::add_reward_v2(
            &acl, &mut p, &mut vault, 0, vector[funds], 100, &clock, &v,
            test_scenario::ctx(&mut s),
        );
        // Seed nonzero emissions as ADMIN, before handing the fixture to OPERATOR.
        // In particular, reset negatives must fail in reset_reward_v2 itself,
        // not in an extra guarded preparatory call by OPERATOR.
        reward_manager::update_reward_emissions_v2(
            &acl, &mut p, 0, 2, &clock, &v, test_scenario::ctx(&mut s),
        );
        assert!(balance::value(pool::get_reward_vault(&vault)) == 100, 100);
        test_scenario::return_shared(acl);
        test_scenario::return_shared(p);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(v);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(&mut s, OPERATOR);
        s
    }

    // Actual sender is OPERATOR. Every negative wrapper names the precise
    // production abort code/module: fixture failures cannot satisfy it.
    fun execute(s: Scenario, action: u8) {
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let config = test_scenario::take_shared<PoolConfig>(&s);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let vault = test_scenario::take_shared<PoolRewardVault<R>>(&s);
        let fee = test_scenario::take_immutable<Fee<FEE1000BPS>>(&s);
        if (action == 0) {
            pool_factory::set_fee_tier_v2(&acl, &mut config, &fee, &v, test_scenario::ctx(&mut s));
        } else if (action == 1) {
            pool_factory::set_fee_protocol_v2(&acl, &mut config, 500000, &v, test_scenario::ctx(&mut s));
        } else if (action == 2) {
            pool_factory::update_pool_fee_protocol_v2(
                &acl, &mut p, 500000, &v, test_scenario::ctx(&mut s),
            );
            assert!(pool::get_pool_fee_protocol(&p) == 500000, 101);
        } else if (action == 3) {
            // Empty pool: this proves the entry authorization, not nonzero fee accounting.
            pool_factory::collect_protocol_fee_v2(
                &acl, &mut p, 0, 0, RECIPIENT, &v, test_scenario::ctx(&mut s),
            );
        } else if (action == 4) {
            let (a, b) = pool_factory::collect_protocol_fee_with_return_v2(
                &acl, &mut p, 0, 0, RECIPIENT, &v, test_scenario::ctx(&mut s),
            );
            assert!(coin::value(&a) == 0 && coin::value(&b) == 0, 102);
            coin::destroy_zero(a);
            coin::destroy_zero(b);
        } else if (action == 5) {
            assert!(pool::get_pool_unlocked(&p), 103);
            pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
            assert!(!pool::get_pool_unlocked(&p), 104);
            pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
            assert!(pool::get_pool_unlocked(&p), 105);
        } else if (action == 6) {
            pool_factory::update_nft_name_v2(
                &acl, &mut positions, string::utf8(b"name"), &v, test_scenario::ctx(&mut s),
            );
        } else if (action == 7) {
            pool_factory::update_nft_description_v2(
                &acl, &mut positions, string::utf8(b"description"), &v, test_scenario::ctx(&mut s),
            );
        } else if (action == 8) {
            pool_factory::update_nft_img_url_v2(
                &acl, &mut positions, string::utf8(b"https://example.org/nft"), &v, test_scenario::ctx(&mut s),
            );
        } else if (action == 9) {
            reward_manager::init_reward_v2<A, B, FEE500BPS, S>(
                &acl, &mut p, 1, RECIPIENT, &v, test_scenario::ctx(&mut s),
            );
            let (_, _, _, manager) = pool::get_reward_info(&p, 1);
            assert!(manager == RECIPIENT, 106);
        } else if (action == 10) {
            reward_manager::reset_reward_v2<A, B, FEE500BPS, R>(
                &acl, &mut p, 0, &v, test_scenario::ctx(&mut s),
            );
            let (_, emissions, growth, _) = pool::get_reward_info(&p, 0);
            assert!(emissions == 0 && growth == 0, 111);
        } else if (action == 11) {
            let funds = coin::mint_for_testing<R>(30, test_scenario::ctx(&mut s));
            reward_manager::add_reward_v2(
                &acl, &mut p, &mut vault, 0, vector[funds], 30, &clock, &v,
                test_scenario::ctx(&mut s),
            );
            assert!(balance::value(pool::get_reward_vault(&vault)) == 130, 107);
        } else if (action == 12) {
            reward_manager::remove_reward_v2(
                &acl, &mut p, &mut vault, 0, 40, RECIPIENT, &clock, &v,
                test_scenario::ctx(&mut s),
            );
            assert!(balance::value(pool::get_reward_vault(&vault)) == 60, 108);
        } else if (action == 13) {
            reward_manager::update_reward_emissions_v2(
                &acl, &mut p, 0, 2, &clock, &v, test_scenario::ctx(&mut s),
            );
            let (_, emissions, _, _) = pool::get_reward_info(&p, 0);
            assert!(emissions == (2u128 << 64), 109);
        } else { abort 199 };
        test_scenario::return_shared(acl);
        test_scenario::return_shared(v);
        test_scenario::return_shared(config);
        test_scenario::return_shared(p);
        test_scenario::return_shared(positions);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(vault);
        test_scenario::return_immutable(fee);
        if (action == 3) {
            test_scenario::next_tx(&mut s, RECIPIENT);
            coin::destroy_zero(test_scenario::take_from_sender<Coin<A>>(&s));
            coin::destroy_zero(test_scenario::take_from_sender<Coin<B>>(&s));
        } else if (action == 12) {
            test_scenario::next_tx(&mut s, RECIPIENT);
            let received = test_scenario::take_from_sender<Coin<R>>(&s);
            assert!(coin::value(&received) == 40, 110);
            coin::burn_for_testing(received);
        };
        test_scenario::end(s);
    }

    fun revoke(s: &mut Scenario, role: u8) {
        test_scenario::next_tx(s, ADMIN);
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(s);
        let acl = test_scenario::take_shared<AclConfig>(s);
        let v = test_scenario::take_shared<Versioned>(s);
        pool_factory::remove_role(&cap, &mut acl, OPERATOR, role, &v);
        test_scenario::return_to_sender(s, cap);
        test_scenario::return_shared(acl);
        test_scenario::return_shared(v);
        test_scenario::next_tx(s, OPERATOR);
    }

    #[test]
    fun set_fee_tier_allows_required_role() { execute(setup(1), 0); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun set_fee_tier_rejects_missing_role() { execute(setup(0), 0); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun set_fee_tier_rejects_other_roles() { execute(setup(14), 0); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun set_fee_tier_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 0);
        execute(s, 0);
    }

    #[test]
    fun set_fee_protocol_allows_required_role() { execute(setup(1), 1); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun set_fee_protocol_rejects_missing_role() { execute(setup(0), 1); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun set_fee_protocol_rejects_other_roles() { execute(setup(14), 1); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun set_fee_protocol_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 0);
        execute(s, 1);
    }

    #[test]
    fun update_pool_fee_protocol_allows_required_role() { execute(setup(1), 2); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_pool_fee_protocol_rejects_missing_role() { execute(setup(0), 2); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_pool_fee_protocol_rejects_other_roles() { execute(setup(14), 2); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_pool_fee_protocol_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 0);
        execute(s, 2);
    }

    #[test]
    fun collect_protocol_fee_allows_required_role() { execute(setup(4), 3); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool_factory)]
    fun collect_protocol_fee_rejects_missing_role() { execute(setup(0), 3); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool_factory)]
    fun collect_protocol_fee_rejects_other_roles() { execute(setup(11), 3); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool_factory)]
    fun collect_protocol_fee_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 2);
        execute(s, 3);
    }

    #[test]
    fun collect_protocol_fee_with_return_allows_required_role() { execute(setup(4), 4); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool_factory)]
    fun collect_protocol_fee_with_return_rejects_missing_role() { execute(setup(0), 4); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool_factory)]
    fun collect_protocol_fee_with_return_rejects_other_roles() { execute(setup(11), 4); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool_factory)]
    fun collect_protocol_fee_with_return_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 2);
        execute(s, 4);
    }

    #[test]
    fun toggle_pool_status_allows_required_role() { execute(setup(8), 5); }

    #[test, expected_failure(abort_code = 9, location = turbos_clmm::pool_factory)]
    fun toggle_pool_status_rejects_missing_role() { execute(setup(0), 5); }

    #[test, expected_failure(abort_code = 9, location = turbos_clmm::pool_factory)]
    fun toggle_pool_status_rejects_other_roles() { execute(setup(7), 5); }

    #[test, expected_failure(abort_code = 9, location = turbos_clmm::pool_factory)]
    fun toggle_pool_status_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 3);
        execute(s, 5);
    }

    #[test]
    fun update_nft_name_allows_required_role() { execute(setup(1), 6); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_nft_name_rejects_missing_role() { execute(setup(0), 6); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_nft_name_rejects_other_roles() { execute(setup(14), 6); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_nft_name_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 0);
        execute(s, 6);
    }

    #[test]
    fun update_nft_description_allows_required_role() { execute(setup(1), 7); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_nft_description_rejects_missing_role() { execute(setup(0), 7); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_nft_description_rejects_other_roles() { execute(setup(14), 7); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_nft_description_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 0);
        execute(s, 7);
    }

    #[test]
    fun update_nft_img_url_allows_required_role() { execute(setup(1), 8); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_nft_img_url_rejects_missing_role() { execute(setup(0), 8); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_nft_img_url_rejects_other_roles() { execute(setup(14), 8); }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun update_nft_img_url_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 0);
        execute(s, 8);
    }

    #[test]
    fun init_reward_allows_required_role() { execute(setup(2), 9); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun init_reward_rejects_missing_role() { execute(setup(0), 9); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun init_reward_rejects_other_roles() { execute(setup(13), 9); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun init_reward_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 1);
        execute(s, 9);
    }

    #[test]
    fun reset_reward_allows_required_role() { execute(setup(2), 10); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun reset_reward_rejects_missing_role() { execute(setup(0), 10); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun reset_reward_rejects_other_roles() { execute(setup(13), 10); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun reset_reward_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 1);
        execute(s, 10);
    }

    #[test]
    fun add_reward_allows_required_role() { execute(setup(2), 11); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun add_reward_rejects_missing_role() { execute(setup(0), 11); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun add_reward_rejects_other_roles() { execute(setup(13), 11); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun add_reward_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 1);
        execute(s, 11);
    }

    #[test]
    fun remove_reward_allows_required_role() { execute(setup(2), 12); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun remove_reward_rejects_missing_role() { execute(setup(0), 12); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun remove_reward_rejects_other_roles() { execute(setup(13), 12); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun remove_reward_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 1);
        execute(s, 12);
    }

    #[test]
    fun update_reward_emissions_allows_required_role() { execute(setup(2), 13); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun update_reward_emissions_rejects_missing_role() { execute(setup(0), 13); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun update_reward_emissions_rejects_other_roles() { execute(setup(13), 13); }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun update_reward_emissions_rejects_revoked_role() {
        let s = setup(15);
        revoke(&mut s, 1);
        execute(s, 13);
    }
}

