// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_acl_tests {
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::pool::{Self, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, AclConfig};
    const ADMIN: address = @0xA;
    const USER: address = @0xB;

    fun setup(): (Scenario, PoolFactoryAdminCap, AclConfig, Versioned) {
        let s = test_scenario::begin(ADMIN);
        pool_factory::init_for_testing(test_scenario::ctx(&mut s));
        pool::init_for_testing(test_scenario::ctx(&mut s));
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(&s);
        pool_factory::init_acl_config(&cap, test_scenario::ctx(&mut s));
        test_scenario::return_to_sender(&s, cap);
        test_scenario::next_tx(&mut s, ADMIN);
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(&s);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let version = test_scenario::take_shared<Versioned>(&s);
        (s, cap, acl, version)
    }

    fun finish(s: Scenario, cap: PoolFactoryAdminCap, acl: AclConfig, version: Versioned) {
        test_scenario::return_to_sender(&s, cap);
        test_scenario::return_shared(acl);
        test_scenario::return_shared(version);
        test_scenario::end(s);
    }

    #[test]
    fun security_each_granted_acl_role_passes_its_check() {
        let (s, cap, acl, version) = setup();
        pool_factory::set_roles(&cap, &mut acl, USER, 15, &version);
        pool_factory::check_clmm_manager_role(&acl, USER);
        pool_factory::check_reward_manager_role(&acl, USER);
        pool_factory::check_claim_protocol_fee_manager_role(&acl, USER);
        pool_factory::check_pause_pool_manager_role(&acl, USER);
        finish(s, cap, acl, version);
    }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun security_missing_clmm_role_is_rejected() {
        let (s, cap, acl, version) = setup();
        pool_factory::check_clmm_manager_role(&acl, USER);
        finish(s, cap, acl, version);
    }

    #[test, expected_failure(abort_code = 7, location = turbos_clmm::pool_factory)]
    fun security_missing_reward_role_is_rejected() {
        let (s, cap, acl, version) = setup();
        pool_factory::check_reward_manager_role(&acl, USER);
        finish(s, cap, acl, version);
    }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool_factory)]
    fun security_missing_fee_role_is_rejected() {
        let (s, cap, acl, version) = setup();
        pool_factory::check_claim_protocol_fee_manager_role(&acl, USER);
        finish(s, cap, acl, version);
    }

    #[test, expected_failure(abort_code = 9, location = turbos_clmm::pool_factory)]
    fun security_missing_pause_role_is_rejected() {
        let (s, cap, acl, version) = setup();
        pool_factory::check_pause_pool_manager_role(&acl, USER);
        finish(s, cap, acl, version);
    }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool_factory)]
    fun security_pause_only_cannot_claim_fees() {
        let (s, cap, acl, version) = setup();
        pool_factory::set_roles(&cap, &mut acl, USER, 8, &version);
        pool_factory::check_pause_pool_manager_role(&acl, USER);
        pool_factory::check_claim_protocol_fee_manager_role(&acl, USER);
        finish(s, cap, acl, version);
    }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::pool_factory)]
    fun security_fee_only_cannot_manage_pool() {
        let (s, cap, acl, version) = setup();
        pool_factory::set_roles(&cap, &mut acl, USER, 4, &version);
        pool_factory::check_claim_protocol_fee_manager_role(&acl, USER);
        pool_factory::check_clmm_manager_role(&acl, USER);
        finish(s, cap, acl, version);
    }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool_factory)]
    fun security_revoked_fee_role_is_rejected() {
        let (s, cap, acl, version) = setup();
        pool_factory::set_roles(&cap, &mut acl, USER, 4, &version);
        pool_factory::check_claim_protocol_fee_manager_role(&acl, USER);
        pool_factory::remove_role(&cap, &mut acl, USER, 2, &version);
        pool_factory::check_claim_protocol_fee_manager_role(&acl, USER);
        finish(s, cap, acl, version);
    }

    #[test, expected_failure(abort_code = 9, location = turbos_clmm::pool_factory)]
    fun security_removed_member_is_rejected() {
        let (s, cap, acl, version) = setup();
        pool_factory::set_roles(&cap, &mut acl, USER, 8, &version);
        pool_factory::remove_member(&cap, &mut acl, USER, &version);
        pool_factory::check_pause_pool_manager_role(&acl, USER);
        finish(s, cap, acl, version);
    }

    #[test, expected_failure(abort_code = 3, location = sui::test_scenario)]
    fun security_non_owner_cannot_take_pool_factory_admin_cap() {
        let s = test_scenario::begin(ADMIN);
        pool_factory::init_for_testing(test_scenario::ctx(&mut s));
        test_scenario::next_tx(&mut s, USER);
        let cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(&s);
        test_scenario::return_to_sender(&s, cap);
        test_scenario::end(s);
    }
}
