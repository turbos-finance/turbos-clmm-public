// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT
#[test_only]
module turbos_clmm::security_metadata_tests {
    use std::bcs;
    use std::string;
    use sui::bcs as reader;
    use sui::clock::Clock;
    use sui::coin;
    use sui::object;
    use sui::test_scenario;
    use sui::transfer;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{Self, AclConfig};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft::{Self, TurbosPositionNFT};
    use turbos_clmm::security_entrypoint_tests::{A, B};
    use turbos_clmm::security_position_tests;

    // Decode only the deployed BCS schema, without adding a production getter:
    // Positions = UID, minted:u64, Table(UID,size:u64), three Strings.
    fun defaults(p: &Positions): (u64, vector<u8>, vector<u8>, vector<u8>) {
        let bytes = reader::new(bcs::to_bytes(p));
        assert!(reader::peel_address(&mut bytes) == object::id_address(p), 1500);
        let count = reader::peel_u64(&mut bytes);
        let _ = reader::peel_address(&mut bytes);
        let _ = reader::peel_u64(&mut bytes);
        let name = reader::peel_vec_u8(&mut bytes);
        let description = reader::peel_vec_u8(&mut bytes);
        let image = reader::peel_vec_u8(&mut bytes);
        assert!(std::vector::is_empty(&reader::into_remainder_bytes(bytes)), 1501);
        (count, name, description, image)
    }

    // NFT prefix = UID, String, String, Url(String), pool ID, position ID.
    fun metadata(nft: &TurbosPositionNFT): (vector<u8>, vector<u8>, vector<u8>) {
        let bytes = reader::new(bcs::to_bytes(nft));
        assert!(reader::peel_address(&mut bytes) == object::id_address(nft), 1502);
        let name = reader::peel_vec_u8(&mut bytes);
        let description = reader::peel_vec_u8(&mut bytes);
        let image = reader::peel_vec_u8(&mut bytes);
        assert!(reader::peel_address(&mut bytes) == object::id_to_address(&position_nft::pool_id(nft)), 1503);
        assert!(reader::peel_address(&mut bytes) == object::id_to_address(&position_nft::position_id(nft)), 1504);
        let _ = reader::into_remainder_bytes(bytes);
        (name, description, image)
    }

    // action: name / description / image / all / unicode / empty. Updates are
    // persisted across transactions before minting; old NFTs must not change.
    fun run(action: u8, recipient: address) {
        let s = security_position_tests::liquid();
        let old = test_scenario::take_from_sender<TurbosPositionNFT>(&s);
        let old_id = object::id(&old);
        let old_bytes = bcs::to_bytes(&old);
        let (old_name, old_description, old_image) = metadata(&old);
        let p = test_scenario::take_shared<Positions>(&s);
        let (count, before_name, before_description, before_image) = defaults(&p);
        assert!(count == 1 && before_name == old_name && before_description == old_description && before_image == old_image, 1505);
        let acl = test_scenario::take_shared<AclConfig>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let name = if (action == 4) b"Turbos \xe6\xb5\x8b\xe8\xaf\x95" else if (action == 5) b"" else b"Reviewed Position";
        let description = if (action == 4) b"\xe5\xae\x89\xe5\x85\xa8\xe5\x9b\x9e\xe5\xbd\x92" else if (action == 5) b"" else b"Verified metadata defaults";
        let image = if (action == 5) b"" else b"https://example.invalid/position.svg";
        if (action == 0 || action >= 3) pool_factory::update_nft_name_v2(&acl, &mut p,
            string::utf8(name), &v, test_scenario::ctx(&mut s));
        if (action == 1 || action >= 3) pool_factory::update_nft_description_v2(&acl, &mut p,
            string::utf8(description), &v, test_scenario::ctx(&mut s));
        if (action == 2 || action >= 3) pool_factory::update_nft_img_url_v2(&acl, &mut p,
            string::utf8(image), &v, test_scenario::ctx(&mut s));
        let expected_name = if (action == 0 || action >= 3) name else before_name;
        let expected_description = if (action == 1 || action >= 3) description else before_description;
        let expected_image = if (action == 2 || action >= 3) image else before_image;
        let (new_count, stored_name, stored_description, stored_image) = defaults(&p);
        assert!(new_count == count && stored_name == expected_name && stored_description == expected_description && stored_image == expected_image, 1506);
        test_scenario::return_to_sender(&s, old);
        test_scenario::return_shared(p); test_scenario::return_shared(acl); test_scenario::return_shared(v);
        test_scenario::next_tx(&mut s, @0xB);
        let positions = test_scenario::take_shared<Positions>(&s);
        let (persisted_count, persisted_name, persisted_description, persisted_image) = defaults(&positions);
        assert!(persisted_count == count && persisted_name == expected_name && persisted_description == expected_description && persisted_image == expected_image, 1507);
        let old = test_scenario::take_from_sender_by_id<TurbosPositionNFT>(&s, old_id);
        assert!(bcs::to_bytes(&old) == old_bytes, 1508);
        let pool = test_scenario::take_shared<Pool<A, B, FEE500BPS>>(&s);
        let clock = test_scenario::take_shared<Clock>(&s);
        let v = test_scenario::take_shared<Versioned>(&s);
        let (before_a, before_b) = pool::get_pool_balance(&pool);
        let a = coin::mint_for_testing<A>(10000, test_scenario::ctx(&mut s));
        let b = coin::mint_for_testing<B>(10000, test_scenario::ctx(&mut s));
        let (nft, a, b) = position_manager::mint_with_return_(&mut pool, &mut positions,
            vector[a], vector[b], 1000, true, 1000, false, 10000, 10000,
            0, 0, 1000, &clock, &v, test_scenario::ctx(&mut s));
        let (n, d, i) = metadata(&nft);
        assert!(n == expected_name && d == expected_description && i == expected_image, 1509);
        assert!(object::id(&nft) != old_id && position_nft::pool_id(&nft) == object::id(&pool), 1510);
        let (_, _, liquidity) = position_manager::get_position_info(&positions, object::id_address(&nft));
        assert!(liquidity > 0 && position_manager::get_nft_minted(&positions) == count + 1, 1511);
        let (after_a, after_b) = pool::get_pool_balance(&pool);
        assert!(after_a + coin::value(&a) == before_a + 10000 && after_b + coin::value(&b) == before_b + 10000, 1512);
        let new_id = object::id(&nft);
        transfer::public_transfer(nft, recipient);
        test_scenario::return_to_sender(&s, old);
        coin::burn_for_testing(a); coin::burn_for_testing(b);
        test_scenario::return_shared(positions); test_scenario::return_shared(pool);
        test_scenario::return_shared(clock); test_scenario::return_shared(v);
        test_scenario::next_tx(&mut s, recipient);
        let received = test_scenario::take_from_sender_by_id<TurbosPositionNFT>(&s, new_id);
        let (n, d, i) = metadata(&received);
        assert!(n == expected_name && d == expected_description && i == expected_image, 1513);
        test_scenario::return_to_sender(&s, received); test_scenario::end(s);
    }

    #[test] fun name_default_persists_and_new_nft_reads_it() { run(0, @0xB); }
    #[test] fun description_default_persists_and_new_nft_reads_it() { run(1, @0xB); }
    #[test] fun image_default_persists_and_new_nft_reads_it() { run(2, @0xB); }
    #[test] fun all_defaults_change_without_rewriting_old_nft() { run(3, @0xB); }
    #[test] fun unicode_name_and_description_round_trip() { run(4, @0xB); }
    #[test] fun empty_metadata_matches_deployed_behavior() { run(5, @0xB); }
    #[test] fun new_recipient_receives_updated_metadata() { run(3, @0xC); }
}
