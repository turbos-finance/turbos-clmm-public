// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::math_liquidity {
    use turbos_clmm::math_u128;
    use turbos_clmm::full_math_u128;
    use turbos_clmm::i128::{Self, I128};

    const EAddDelta: u64 = 0;

    const Q64: u128 = 0x10000000000000000;

    public fun get_liquidity_for_amounts(
        sqrt_price: u128,
        sqrt_price_a: u128,
        sqrt_price_b: u128,
        amount_a: u128,
        amount_b: u128
    ): u128 {
        let liquidity;
        if (sqrt_price_a > sqrt_price_b) (sqrt_price_a, sqrt_price_b) = (sqrt_price_b, sqrt_price_a);

        if (sqrt_price <= sqrt_price_a) {
            liquidity = get_liquidity_for_amount_a(sqrt_price_a, sqrt_price_b, amount_a);
        } else if (sqrt_price < sqrt_price_b) {
            let liquidity_a = get_liquidity_for_amount_a(sqrt_price, sqrt_price_b, amount_a);
            let liquidity_b = get_liquidity_for_amount_b(sqrt_price_a, sqrt_price, amount_b);

            liquidity = if (liquidity_a < liquidity_b) liquidity_a else liquidity_b;
        } else {
            liquidity = get_liquidity_for_amount_b(sqrt_price_a, sqrt_price_b, amount_b);
        };

        liquidity
    }

    public fun  get_liquidity_for_amount_a(
        sqrt_price_a: u128,
        sqrt_price_b: u128,
        amount_a: u128,
    ): u128 {
        if (sqrt_price_a > sqrt_price_b) (sqrt_price_a, sqrt_price_b) = (sqrt_price_b, sqrt_price_a);
        let intermediate = full_math_u128::mul_div_floor(sqrt_price_a, sqrt_price_b, Q64);

        full_math_u128::mul_div_floor(amount_a, intermediate, sqrt_price_b - sqrt_price_a)
    }

    public fun  get_liquidity_for_amount_b(
        sqrt_price_a: u128,
        sqrt_price_b: u128,
        amount_b: u128,
    ): u128 {
        if (sqrt_price_a > sqrt_price_b) (sqrt_price_a, sqrt_price_b) = (sqrt_price_b, sqrt_price_a);

        full_math_u128::mul_div_floor(amount_b, Q64, sqrt_price_b - sqrt_price_a)
    }

    public fun add_delta(x: u128, y: I128): u128 {
        let z;
        if (i128::is_neg(y)) {
            z = x - i128::as_u128(y);
            assert!(z < x, EAddDelta);
        } else {
            z = x + i128::as_u128(y);
            assert!(z >= x, EAddDelta);
        };

        z
    }
}
