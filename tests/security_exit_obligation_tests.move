// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_exit_obligation_tests {
    use sui::balance;
    use sui::clock::{Self, Clock};
    use sui::coin;
    use sui::object;
    use sui::test_scenario;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::i32;
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault, Versioned};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft::TurbosPositionNFT;
    use turbos_clmm::security_entrypoint_tests::{A, B, R};
    use turbos_clmm::security_position_tests;
    use turbos_clmm::swap_router;

    // kind A fee / B fee / reward. A zero-liquidity position is not cleared if
    // any fee or reward remains owed. Partial collection is not a full discharge.
    fun run(kind: u8, collection: u8) {
        let s = security_position_tests::liquid();
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let vault = test_scenario::take_shared<PoolRewardVault<R>>(&s);
        if (kind == 2) clock::set_for_testing(&mut clock, 10000);
        if (kind < 2) {
            if (kind == 0) {
                let input = coin::mint_for_testing<A>(100000, test_scenario::ctx(&mut s));
                let (out, refund) = swap_router::swap_a_b_with_return_(&mut p, vector[input],
                    100000, 0, 4295048016, true, @0xB, 10000, &clock, &v, test_scenario::ctx(&mut s));
                coin::burn_for_testing(out); coin::destroy_zero(refund);
            } else {
                let input = coin::mint_for_testing<B>(100000, test_scenario::ctx(&mut s));
                let (out, refund) = swap_router::swap_b_a_with_return_(&mut p, vector[input],
                    100000, 0, 79226673515401279992447579055, true, @0xB, 10000, &clock, &v, test_scenario::ctx(&mut s));
                coin::burn_for_testing(out); coin::destroy_zero(refund);
            };
        };
        let address = object::id_address(&nft);
        let (_, _, liquidity) = position_manager::get_position_info(&positions, address);
        let (principal_a, principal_b) = position_manager::decrease_liquidity_with_return_(
            &mut p, &mut positions, &mut nft, liquidity, 0, 0, 10000, &clock, &v,
            test_scenario::ctx(&mut s));
        coin::burn_for_testing(principal_a); coin::burn_for_testing(principal_b);
        let key = pool::get_position_key_fix(&p, address, i32::neg_from(1000), i32::from(1000));
        let (remaining_l, _, _, fee_a, fee_b, rewards) = pool::get_position_base_info(&p, key);
        assert!(remaining_l == 0, 1300);
        let (_, reward_owed) = pool::get_position_reward_info(std::vector::borrow(rewards, 0));
        let owed = if (kind == 0) fee_a else if (kind == 1) fee_b else reward_owed;
        assert!(owed > 1, 1301);
        if (kind == 0) assert!(fee_b == 0 && reward_owed == 0, 1302)
        else if (kind == 1) assert!(fee_a == 0 && reward_owed == 0, 1303)
        else assert!(fee_a == 0 && fee_b == 0, 1304);
        if (collection > 0) {
            let amount = if (collection == 1) owed - 1 else owed;
            if (kind < 2) {
                let (before_a, before_b) = pool::get_pool_balance(&p);
                let (a, b) = position_manager::collect_with_return_(&mut p, &mut positions,
                    &mut nft, if (kind == 0) amount else 0, if (kind == 1) amount else 0,
                    @0xB, 10000, &clock, &v, test_scenario::ctx(&mut s));
                assert!(coin::value(&a) == (if (kind == 0) amount else 0) &&
                    coin::value(&b) == (if (kind == 1) amount else 0), 1305);
                let (after_a, after_b) = pool::get_pool_balance(&p);
                assert!(after_a + coin::value(&a) == before_a && after_b + coin::value(&b) == before_b, 1306);
                coin::burn_for_testing(a); coin::burn_for_testing(b);
            } else {
                let before = balance::value(pool::get_reward_vault(&vault));
                let r = position_manager::collect_reward_with_return_(&mut p, &mut positions,
                    &mut nft, &mut vault, 0, amount, @0xB, 10000, &clock, &v, test_scenario::ctx(&mut s));
                assert!(coin::value(&r) == amount && balance::value(pool::get_reward_vault(&vault)) + amount == before, 1307);
                coin::burn_for_testing(r);
            };
        };
        position_manager::burn<A, B, FEE500BPS>(&mut positions, nft, &v, test_scenario::ctx(&mut s));
        test_scenario::return_shared(p); test_scenario::return_shared(positions);
        test_scenario::return_shared(v); test_scenario::return_shared(clock);
        test_scenario::return_shared(vault); test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 6, location = turbos_clmm::position_manager)]
    fun fee_a_owed_blocks_zero_liquidity_nft_burn() { run(0, 0); }
    #[test, expected_failure(abort_code = 6, location = turbos_clmm::position_manager)]
    fun fee_b_owed_blocks_zero_liquidity_nft_burn() { run(1, 0); }
    #[test, expected_failure(abort_code = 6, location = turbos_clmm::position_manager)]
    fun reward_owed_blocks_zero_liquidity_nft_burn() { run(2, 0); }
    #[test, expected_failure(abort_code = 6, location = turbos_clmm::position_manager)]
    fun partial_fee_a_claim_does_not_clear_position() { run(0, 1); }
    #[test, expected_failure(abort_code = 6, location = turbos_clmm::position_manager)]
    fun partial_fee_b_claim_does_not_clear_position() { run(1, 1); }
    #[test, expected_failure(abort_code = 6, location = turbos_clmm::position_manager)]
    fun partial_reward_claim_does_not_clear_position() { run(2, 1); }
    #[test] fun complete_fee_a_claim_allows_burn() { run(0, 2); }
    #[test] fun complete_fee_b_claim_allows_burn() { run(1, 2); }
    #[test] fun complete_reward_claim_allows_burn() { run(2, 2); }
}
