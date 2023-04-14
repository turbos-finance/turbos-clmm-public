// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::position_nft {
    use std::vector;
    use sui::transfer;
    use sui::url::{Self, Url};
    use std::string::{Self, utf8, String};
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::display;
    use sui::package;
    use sui::tx_context::{Self, TxContext};

	friend turbos_clmm::position_manager;

    struct TurbosPositionNFT<phantom CoinTypeA, phantom CoinTypeB, phantom FeeType> has key, store {
        id: UID,
        name: String,
        description: String,
        img_url: Url,
        pool_id: ID,
        position_id: ID,
    }

    struct TURBOSNFT has drop {}

    struct MintNFTEvent has copy, drop {
        object_id: ID,
        creator: address,
        name: String,
    }

    public fun init_once<CoinTypeA, CoinTypeB, FeeType>(nft: TURBOSNFT, ctx: &mut TxContext) {
        let display_keys = vector::empty();
        vector::push_back(&mut display_keys, utf8(b"name"));
        vector::push_back(&mut display_keys, utf8(b"description"));
        vector::push_back(&mut display_keys, utf8(b"image_url"));
        vector::push_back(&mut display_keys, utf8(b"project_url"));
        vector::push_back(&mut display_keys, utf8(b"creator"));

        let display_values = vector::empty();
        vector::push_back(&mut display_values, utf8(b"{name}"));
        vector::push_back(&mut display_values, utf8(b"{description}"));
        vector::push_back(&mut display_values, utf8(b"{img_url}"));
        vector::push_back(&mut display_values, utf8(b"https://turbos.finance"));
        vector::push_back(&mut display_values, utf8(b"Turbos Team"));

        let publisher = package::claim(nft, ctx);
        let display = display::new<TurbosPositionNFT<CoinTypeA, CoinTypeB, FeeType>>(&publisher, ctx);

        display::add_multiple<TurbosPositionNFT<CoinTypeA, CoinTypeB, FeeType>>(&mut display, display_keys, display_values);
        display::update_version<TurbosPositionNFT<CoinTypeA, CoinTypeB, FeeType>>(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    /// Create a new position_nft
    public(friend) fun mint<CoinTypeA, CoinTypeB, FeeType>(
        name: vector<u8>,
        description: vector<u8>,
        img_url: vector<u8>,
        pool_id: ID,
        position_id: ID,
        ctx: &mut TxContext
    ): TurbosPositionNFT<CoinTypeA, CoinTypeB, FeeType> {
        let nft = TurbosPositionNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            img_url: url::new_unsafe_from_bytes(img_url),
            pool_id,
            position_id,
        };
        let sender = tx_context::sender(ctx);
        event::emit(MintNFTEvent {
            object_id: object::uid_to_inner(&nft.id),
            creator: sender,
            name: nft.name,
        });

		nft
    }

    /// Permanently delete `nft`
    public entry fun burn<CoinTypeA, CoinTypeB, FeeType>(nft: TurbosPositionNFT<CoinTypeA, CoinTypeB, FeeType>) {
        let TurbosPositionNFT { id, name: _, description: _, img_url: _, pool_id: _, position_id: _ } = nft;
        object::delete(id)
    }
}