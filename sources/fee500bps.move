// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::fee500bps {

	use sui::transfer;
	use sui::tx_context::{Self, TxContext};
	use turbos_clmm::fee::{Self, Fee};

	struct FEE500BPS has drop {}
	
	fun init(witness: FEE500BPS, ctx: &mut TxContext) {
		let fee = fee::create_fee(
			witness,
			500,
			ctx
		);

		transfer::freeze_object(fee);
    }
}