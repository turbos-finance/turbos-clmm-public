// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::position_nft {
    use sui::url::{Self, Url};
    use std::string;
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::tx_context::{Self, TxContext};

	friend turbos_clmm::position_manager;

    struct TurbosPositionNFT<phantom CoinTypeA, phantom CoinTypeB, phantom FeeType> has key, store {
        id: UID,
        /// Name for the token
        name: string::String,
        /// Description of the token
        description: string::String,
        /// URL for the token
        url: Url,
        // TODO: allow custom attributes
    }

    struct MintNFTEvent has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The creator of the NFT
        creator: address,
        // The name of the NFT
        name: string::String,
    }

    /// Create a new position_nft
    public(friend) fun mint<CoinTypeA, CoinTypeB, FeeType>(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ): TurbosPositionNFT<CoinTypeA, CoinTypeB, FeeType> {
        let nft = TurbosPositionNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url)
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
        let TurbosPositionNFT { id, name: _, description: _, url: _ } = nft;
        object::delete(id)
    }

	/// Get the NFT's `id`
    public fun nft_address<CoinTypeA, CoinTypeB, FeeType>(nft: &TurbosPositionNFT<CoinTypeA, CoinTypeB, FeeType>): address {
        let nft_address = object::uid_to_address(&nft.id);

		nft_address
    }

    /// Get the NFT's `name`
    public fun name<CoinTypeA, CoinTypeB, FeeType>(nft: &TurbosPositionNFT<CoinTypeA, CoinTypeB, FeeType>): &string::String {
        &nft.name
    }

    /// Get the NFT's `description`
    public fun description<CoinTypeA, CoinTypeB, FeeType>(nft: &TurbosPositionNFT<CoinTypeA, CoinTypeB, FeeType>): &string::String {
        &nft.description
    }

    /// Get the NFT's `url`
    public fun url<CoinTypeA, CoinTypeB, FeeType>(nft: &TurbosPositionNFT<CoinTypeA, CoinTypeB, FeeType>): &Url {
        &nft.url
    }
}