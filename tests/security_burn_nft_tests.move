// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_burn_nft_tests {
    use sui::clock::{Self, Clock};
    use sui::coin;
    use sui::test_scenario::{Self, Scenario};
    use sui::transfer;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::fee1000bps::FEE1000BPS;
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault, Versioned};
    use turbos_clmm::pool_factory::{Self, AclConfig};
    use turbos_clmm::position_manager::{Self, Positions, TurbosPositionBurnNFT};
    use turbos_clmm::position_nft::TurbosPositionNFT;
    use turbos_clmm::security_entrypoint_tests::{Self, A, B, R};
    use turbos_clmm::security_position_tests;
    const OWNER: address = @0xB;
    const OTHER: address = @0xC;

    public fun proof(): Scenario {
        let s = security_entrypoint_tests::setup(15);
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let a = coin::mint_for_testing<A>(1000000, test_scenario::ctx(&mut s));
        let b = coin::mint_for_testing<B>(1000000, test_scenario::ctx(&mut s));
        // Full supported tick range aligned to the actual spacing of 10.
        let (nft, a, b) = position_manager::mint_with_return_(
            &mut p, &mut positions, vector[a], vector[b], 443630, true, 443630, false,
            1000000, 1000000, 0, 0, 1000, &clock, &v, test_scenario::ctx(&mut s),
        );
        coin::burn_for_testing(a); coin::burn_for_testing(b);
        let liquidity = pool::get_pool_liquidity(&p);
        let (before_a, before_b) = pool::get_pool_balance(&p);
        assert!(liquidity > 0, 900);
        let proof = position_manager::burn_position_nft_with_return_(
            &mut p, &mut positions, nft, &v, test_scenario::ctx(&mut s),
        );
        let (after_a, after_b) = pool::get_pool_balance(&p);
        assert!(pool::get_pool_liquidity(&p) == liquidity, 901);
        assert!(after_a == before_a && after_b == before_b, 902);
        transfer::public_transfer(proof, OWNER);
        test_scenario::return_shared(p); test_scenario::return_shared(positions);
        test_scenario::return_shared(clock); test_scenario::return_shared(v);
        test_scenario::next_tx(&mut s, OWNER); s
    }

    // 0 fee collection, 1 reward collection; mode 1 wrong pool, 2 expired, 3 paused, 4 new owner.
    fun collect(action: u8, mode: u8) {
        let s = proof();
        if (mode == 1) security_position_tests::second_pool(&mut s);
        if (mode == 4) {
            let proof = test_scenario::take_from_sender<TurbosPositionBurnNFT>(&s);
            transfer::public_transfer(proof, OTHER);
            test_scenario::next_tx(&mut s, OTHER);
        };
        let proof = test_scenario::take_from_sender<TurbosPositionBurnNFT>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let vault = test_scenario::take_shared<PoolRewardVault<R>>(&s);
        if (mode == 2) clock::set_for_testing(&mut clock, 1);
        let deadline = if (mode == 2) 0 else 1000;
        if (mode == 1) {
            let wrong = test_scenario::take_shared<Pool<A, B, FEE1000BPS>>(&s);
            if (action == 0) {
                let (a, b) = position_manager::burn_nft_collect_fee_with_return_(
                    &mut wrong, &mut positions, &mut proof, 1000000, 1000000, deadline,
                    &clock, &v, test_scenario::ctx(&mut s),
                );
                coin::burn_for_testing(a); coin::burn_for_testing(b);
            } else {
                let r = position_manager::burn_nft_collect_reward_with_return_(
                    &mut wrong, &mut positions, &mut proof, &mut vault, 0, 1000000,
                    deadline, &clock, &v, test_scenario::ctx(&mut s),
                );
                coin::burn_for_testing(r);
            };
            test_scenario::return_shared(wrong);
        } else {
            let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
            if (mode == 3) {
                let acl = test_scenario::take_shared<AclConfig>(&s);
                pool_factory::toggle_pool_status_v2(&acl, &mut p, &v, test_scenario::ctx(&mut s));
                test_scenario::return_shared(acl);
            };
            if (action == 0) {
                let (a, b) = position_manager::burn_nft_collect_fee_with_return_(
                    &mut p, &mut positions, &mut proof, 1000000, 1000000, deadline,
                    &clock, &v, test_scenario::ctx(&mut s),
                );
                assert!(coin::value(&a) == 0 && coin::value(&b) == 0, 903);
                coin::destroy_zero(a); coin::destroy_zero(b);
            } else {
                let r = position_manager::burn_nft_collect_reward_with_return_(
                    &mut p, &mut positions, &mut proof, &mut vault, 0, 1000000,
                    deadline, &clock, &v, test_scenario::ctx(&mut s),
                );
                assert!(coin::value(&r) == 0, 904); coin::destroy_zero(r);
            };
            test_scenario::return_shared(p);
        };
        test_scenario::return_to_sender(&s, proof);
        test_scenario::return_shared(positions); test_scenario::return_shared(clock);
        test_scenario::return_shared(v); test_scenario::return_shared(vault);
        test_scenario::end(s);
    }

    #[test]
    fun proof_conversion_preserves_pool_liquidity_and_balances() { test_scenario::end(proof()); }

    #[test, expected_failure(abort_code = 16, location = turbos_clmm::position_manager)]
    fun narrow_position_cannot_convert_to_burn_proof() {
        let s = security_position_tests::liquid();
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let proof = position_manager::burn_position_nft_with_return_(
            &mut p, &mut positions, nft, &v, test_scenario::ctx(&mut s),
        );
        transfer::public_transfer(proof, OWNER); test_scenario::return_shared(p);
        test_scenario::return_shared(positions); test_scenario::return_shared(v);
        test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 15, location = turbos_clmm::position_manager)]
    fun wrong_pool_cannot_convert_position_to_proof() {
        let s = security_position_tests::liquid();
        security_position_tests::second_pool(&mut s);
        let wrong = test_scenario::take_shared<Pool<A, B, FEE1000BPS>>(&s);
        let positions = test_scenario::take_shared<Positions>(&s);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let proof = position_manager::burn_position_nft_with_return_(
            &mut wrong, &mut positions, nft, &v, test_scenario::ctx(&mut s),
        );
        transfer::public_transfer(proof, OWNER); test_scenario::return_shared(wrong);
        test_scenario::return_shared(positions); test_scenario::return_shared(v);
        test_scenario::end(s);
    }

    #[test, expected_failure(abort_code = 3, location = sui::test_scenario)]
    fun non_owner_cannot_take_burn_proof() {
        let s = proof(); test_scenario::next_tx(&mut s, OTHER);
        let proof = test_scenario::take_from_sender<TurbosPositionBurnNFT>(&s);
        test_scenario::return_to_sender(&s, proof); test_scenario::end(s);
    }

    #[test]
    fun direct_nft_burn_does_not_transfer_pool_assets() {
        let s = security_position_tests::liquid();
        let p = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let nft = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        let (a, b) = pool::get_pool_balance(&p); let l = pool::get_pool_liquidity(&p);
        // This intentionally destroys the owner's access NFT, not the pool position.
        position_manager::burn_nft_directly(nft);
        let (after_a, after_b) = pool::get_pool_balance(&p);
        assert!(a == after_a && b == after_b && l == pool::get_pool_liquidity(&p), 905);
        test_scenario::return_shared(p); test_scenario::end(s);
    }

    #[test]
    fun proof_fee_collection() { collect(0, 0); }

    #[test]
    fun proof_fee_new_owner_collection() { collect(0, 4); }

    #[test, expected_failure(abort_code = 15, location = turbos_clmm::position_manager)]
    fun proof_fee_wrong_pool() { collect(0, 1); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun proof_fee_expired() { collect(0, 2); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun proof_fee_paused() { collect(0, 3); }

    #[test]
    fun proof_reward_collection() { collect(1, 0); }

    #[test]
    fun proof_reward_new_owner_collection() { collect(1, 4); }

    #[test, expected_failure(abort_code = 15, location = turbos_clmm::position_manager)]
    fun proof_reward_wrong_pool() { collect(1, 1); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::position_manager)]
    fun proof_reward_expired() { collect(1, 2); }

    #[test, expected_failure(abort_code = 8, location = turbos_clmm::pool)]
    fun proof_reward_paused() { collect(1, 3); }

}
