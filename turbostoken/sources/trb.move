// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

/// Coin<TRB> is the token of turbos.finance
/// It has 9 decimals
module turbos_token::trb {
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self};
    use std::option;
    use sui::url::{Self};

    struct TRB has drop {}

    fun init(witness: TRB, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            9, 
            b"TURBOS",  // symbols
            b"Turbos",  // name
            b"Turbos Finance Token", // description
            option::some(url::new_unsafe_from_bytes(b"https://ipfs.io/ipfs/QmTxRsWbrLG6mkjg375wW77Lfzm38qsUQjRBj3b2K3t8q1?filename=Turbos_nft.png")), 
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TRB{}, ctx);
    }
}
