// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
// Only executed with an explicitly disclosed test-only rekey overlay.
#[test_only]
module turbos_clmm::legacy_position_fixture_tests {
    use std::bcs;
    use sui::balance;
    use sui::clock::{Self, Clock};
    use sui::coin;
    use sui::object;
    use sui::test_scenario::{Self, Scenario};
    use sui::transfer;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::i32;
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault, Versioned};
    use turbos_clmm::pool_factory::{Self, AclConfig};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft::TurbosPositionNFT;
    use turbos_clmm::security_entrypoint_tests::{Self, A, B, R};
    use turbos_clmm::swap_router;
    const OWNER: address = @0xB;
    const OTHER: address = @0xC;

    // Zero lower tick deliberately distinguishes historical +0 from current -0.
    // The overlay changes only the dynamic-field key of a genuinely minted record.
    fun setup(old: bool): Scenario {
        let s = security_entrypoint_tests::setup(15);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let a = coin::mint_for_testing<A>(1000000, test_scenario::ctx(&mut s));
        let b = coin::mint_for_testing<B>(1000000, test_scenario::ctx(&mut s));
        let (nft, a, b) = position_manager::mint_with_return_(&mut p, &mut positions,
            vector[a], vector[b], 0, false, 1000, false, 1000000, 1000000,
            0, 0, 10000, &clock, &v, test_scenario::ctx(&mut s));
        let address = object::id_address(&nft);
        let bytes = bcs::to_bytes(&p);
        let original = bcs::to_bytes(pool::get_position(&p, address, i32::zero(), i32::from(1000)));
        pool::security_rekey_position_fixture(&mut p, address, OWNER, i32::zero(), i32::from(1000), old);
        assert!(bytes == bcs::to_bytes(&p), 1600);
        assert!(original == bcs::to_bytes(pool::get_position(&p, OWNER, i32::zero(), i32::from(1000))), 1601);
        assert!(!pool::check_position_exists(&p, address, i32::zero(), i32::from(1000)), 1602);
        assert!(pool::check_position_exists(&p, OWNER, i32::zero(), i32::from(1000)), 1603);
        assert!(pool::check_position_exists_old(&p, OWNER, i32::zero(), i32::from(1000)) == old, 1604);
        let key = pool::get_position_key_fix(&p, OWNER, i32::zero(), i32::from(1000));
        assert!(key == (if (old) pool::get_position_key_old(OWNER, i32::zero(), i32::from(1000))
            else pool::get_position_key(OWNER, i32::zero(), i32::from(1000))), 1605);
        transfer::public_transfer(nft, OWNER);
        coin::burn_for_testing(a); coin::burn_for_testing(b);
        test_scenario::return_shared(p); test_scenario::return_shared(positions);
        test_scenario::return_shared(clock); test_scenario::return_shared(v);
        test_scenario::next_tx(&mut s, OWNER);
        s
    }

    // action increase / decrease / fee / reward; mode normal / pause / deadline /
    // transferred-holder / transferred-then-returned. No bypassed business checks.
    fun run(old: bool, action: u8, mode: u8) {
        let s = setup(old);
        if (mode == 3 || mode == 4) {
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
            transfer::public_transfer(nft, OTHER);
            test_scenario::next_tx(&mut s, OTHER);
            if (mode == 4) {
                let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
                transfer::public_transfer(nft, OWNER);
                test_scenario::next_tx(&mut s, OWNER);
            };
        };
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let vault = test_scenario::take_shared<PoolRewardVault<R>>(&s);
        if (action == 2) {
            let input = coin::mint_for_testing<B>(100000, test_scenario::ctx(&mut s));
            let (out, refund) = swap_router::swap_b_a_with_return_(&mut p, vector[input],
                100000, 0, 79226673515401279992447579055, true, OWNER, 10000,
                &clock, &v, test_scenario::ctx(&mut s));
            coin::burn_for_testing(out); coin::destroy_zero(refund);
        };
        if (action == 3) clock::set_for_testing(&mut clock, 10000)
        else clock::set_for_testing(&mut clock, 1);
        if (mode == 1) {
            let acl = test_scenario::take_shared<AclConfig>(&s);
            pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
            test_scenario::return_shared(acl);
        };
        let deadline = if (mode == 2) 0 else 10000;
        let (_, _, before_l) = position_manager::get_position_info(&positions, object::id_address(&nft));
        let (before_a, before_b) = pool::get_pool_balance(&p);
        let old_record = bcs::to_bytes(pool::get_position(&p, OWNER, i32::zero(), i32::from(1000)));
        if (action == 0) {
            let a = coin::mint_for_testing<A>(10000, test_scenario::ctx(&mut s));
            let b = coin::mint_for_testing<B>(10000, test_scenario::ctx(&mut s));
            let (a, b) = position_manager::increase_liquidity_with_return_(&mut p, &mut positions,
                vector[a], vector[b], &mut nft, 10000, 10000, 0, 0, deadline, &clock, &v, test_scenario::ctx(&mut s));
            let (after_a, after_b) = pool::get_pool_balance(&p);
            assert!(after_a + coin::value(&a) == before_a + 10000 && after_b + coin::value(&b) == before_b + 10000, 1606);
            coin::burn_for_testing(a); coin::burn_for_testing(b);
            if (mode == 3) {
                assert!(old_record == bcs::to_bytes(pool::get_position(&p, OWNER, i32::zero(), i32::from(1000))), 1607);
                assert!(pool::check_position_exists(&p, OTHER, i32::zero(), i32::from(1000)), 1608);
            };
        } else if (action == 1) {
            let (a, b) = position_manager::decrease_liquidity_with_return_(&mut p, &mut positions,
                &mut nft, before_l / 2, 0, 0, deadline, &clock, &v, test_scenario::ctx(&mut s));
            let (after_a, after_b) = pool::get_pool_balance(&p);
            assert!(after_a + coin::value(&a) == before_a && after_b + coin::value(&b) == before_b, 1609);
            coin::burn_for_testing(a); coin::burn_for_testing(b);
        } else if (action == 2) {
            let (a, b) = position_manager::collect_with_return_(&mut p, &mut positions, &mut nft,
                18446744073709551615, 18446744073709551615, OWNER, deadline,
                &clock, &v, test_scenario::ctx(&mut s));
            assert!(coin::value(&a) == 0 && coin::value(&b) > 0, 1610);
            let (after_a, after_b) = pool::get_pool_balance(&p);
            assert!(after_a + coin::value(&a) == before_a && after_b + coin::value(&b) == before_b, 1611);
            coin::burn_for_testing(a); coin::burn_for_testing(b);
        } else {
            let before = balance::value(pool::get_reward_vault(&vault));
            let r = position_manager::collect_reward_with_return_(&mut p, &mut positions, &mut nft,
                &mut vault, 0, 100, OWNER, deadline, &clock, &v, test_scenario::ctx(&mut s));
            assert!(coin::value(&r) > 0 && balance::value(pool::get_reward_vault(&vault)) + coin::value(&r) == before, 1612);
            let (after_a, after_b) = pool::get_pool_balance(&p);
            assert!(after_a == before_a && after_b == before_b, 1613);
            coin::burn_for_testing(r);
        };
        let (_, _, after_l) = position_manager::get_position_info(&positions, object::id_address(&nft));
        let owner = if (mode == 3) OTHER else OWNER;
        let key = pool::get_position_key_fix(&p, owner, i32::zero(), i32::from(1000));
        let (pool_l, _, _, _, _, _) = pool::get_position_base_info(&p, key);
        assert!(after_l == pool_l && pool_l > 0, 1614);
        if (action == 0 && mode != 3) assert!(after_l > before_l, 1615)
        else if (action == 1) assert!(after_l + before_l / 2 == before_l, 1616)
        else if (action > 1) assert!(after_l == before_l, 1617);
        test_scenario::return_to_sender(&s, nft);
        test_scenario::return_shared(p); test_scenario::return_shared(positions);
        test_scenario::return_shared(v); test_scenario::return_shared(clock);
        test_scenario::return_shared(vault); test_scenario::end(s);
    }

    #[test] fun old_key_increase_conserves() { run(true, 0, 0); }
    #[test] fun old_key_decrease_conserves() { run(true, 1, 0); }
    #[test] fun old_key_fee_collection_conserves() { run(true, 2, 0); }
    #[test] fun old_key_reward_collection_conserves() { run(true, 3, 0); }
    #[test] fun current_key_owner_increase_conserves() { run(false, 0, 0); }
    #[test] fun current_key_owner_decrease_conserves() { run(false, 1, 0); }
    #[test] fun current_key_owner_fee_collection_conserves() { run(false, 2, 0); }
    #[test] fun current_key_owner_reward_collection_conserves() { run(false, 3, 0); }
    #[test] fun old_key_nft_return_restores_original_owner_access() { run(true, 1, 4); }
    #[test] fun current_key_nft_return_restores_original_owner_access() { run(false, 1, 4); }
    #[test] fun transferred_old_nft_increase_does_not_move_original_record() { run(true, 0, 3); }
    #[test] fun transferred_current_key_nft_increase_does_not_move_original_record() { run(false, 0, 3); }
    #[test, expected_failure(abort_code = 1, location = sui::dynamic_field)]
    fun transferred_old_nft_cannot_decrease_original_record() { run(true, 1, 3); }
    #[test, expected_failure(abort_code = 1, location = sui::dynamic_field)]
    fun transferred_old_nft_cannot_claim_original_fee() { run(true, 2, 3); }
    #[test, expected_failure(abort_code = 1, location = sui::dynamic_field)]
    fun transferred_old_nft_cannot_claim_original_reward() { run(true, 3, 3); }
    #[test, expected_failure(abort_code = 1, location = sui::dynamic_field)]
    fun transferred_current_key_nft_cannot_decrease_original_record() { run(false, 1, 3); }
    #[test, expected_failure(abort_code = 1, location = sui::dynamic_field)]
    fun transferred_current_key_nft_cannot_claim_original_fee() { run(false, 2, 3); }
    #[test, expected_failure(abort_code = 1, location = sui::dynamic_field)]
    fun transferred_current_key_nft_cannot_claim_original_reward() { run(false, 3, 3); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun old_key_pause_blocks_increase() { run(true, 0, 1); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun old_key_pause_blocks_decrease() { run(true, 1, 1); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun old_key_pause_blocks_fee_collection() { run(true, 2, 1); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun old_key_pause_blocks_reward_collection() { run(true, 3, 1); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun current_key_pause_blocks_increase() { run(false, 0, 1); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun current_key_pause_blocks_decrease() { run(false, 1, 1); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun current_key_pause_blocks_fee_collection() { run(false, 2, 1); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun current_key_pause_blocks_reward_collection() { run(false, 3, 1); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun old_key_expired_increase_rejects() { run(true, 0, 2); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun old_key_expired_decrease_rejects() { run(true, 1, 2); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun old_key_expired_fee_collection_rejects() { run(true, 2, 2); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun old_key_expired_reward_collection_rejects() { run(true, 3, 2); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun current_key_expired_increase_rejects() { run(false, 0, 2); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun current_key_expired_decrease_rejects() { run(false, 1, 2); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun current_key_expired_fee_collection_rejects() { run(false, 2, 2); }
    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun current_key_expired_reward_collection_rejects() { run(false, 3, 2); }
}
