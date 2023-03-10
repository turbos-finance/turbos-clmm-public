// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::math_sqrt_price {
    use turbos_clmm::math_u128;
    use turbos_clmm::full_math_u128;
    use turbos_clmm::i128::{Self, I128};

    const EInvildSqrtPrice: u64 = 0;

    const RESOLUTION: u8 = 64;
    const Q64: u128 = 0x10000000000000000;

    /// @notice Gets the amount0 delta between two prices
    /// @dev Calculates liquidity / sqrt(lower) - liquidity / sqrt(upper),
    /// i.e. liquidity * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
    /// @param sqrt_price_a A sqrt price
    /// @param sqrt_price_b Another sqrt price
    /// @param liquidity The amount of usable liquidity
    /// @param round_up Whether to round the amount up or down
    /// @return amount0 Amount of token0 required to cover a position of size liquidity between the two passed prices
    public fun get_amount_a_delta_(
        sqrt_price_a: u128,
        sqrt_price_b: u128,
        liquidity: u128,
        round_up: bool,
    ): u128 {
        if (sqrt_price_a > sqrt_price_b) (sqrt_price_a, sqrt_price_b) = (sqrt_price_b, sqrt_price_a);

        let numerator1 = liquidity << RESOLUTION;
        let numerator2 = sqrt_price_b - sqrt_price_a;

        assert!(sqrt_price_a > 0, EInvildSqrtPrice);

        let amount_a;
        if (round_up) {
            amount_a = math_u128::checked_div_round(
                full_math_u128::mul_div_round(numerator1, numerator2, sqrt_price_b),
                sqrt_price_a,
                true
            );
        } else {
            amount_a = full_math_u128::mul_div_floor(numerator1, numerator2, sqrt_price_b) / sqrt_price_a;
        };

        amount_a
    }

    /// @notice Gets the amount1 delta between two prices
    /// @dev Calculates liquidity * (sqrt(upper) - sqrt(lower))
    /// @param sqrt_price_a A sqrt price
    /// @param sqrt_price_b Another sqrt price
    /// @param liquidity The amount of usable liquidity
    /// @param round_up Whether to round the amount up, or down
    /// @return amount1 Amount of token1 required to cover a position of size liquidity between the two passed prices
    public fun get_amount_b_delta_(
        sqrt_price_a: u128,
        sqrt_price_b: u128,
        liquidity: u128,
        round_up: bool,
    ): u128 {
        if (sqrt_price_a > sqrt_price_b) (sqrt_price_a, sqrt_price_b) = (sqrt_price_b, sqrt_price_a);

        let amount_b;
        if (round_up) {
            amount_b = full_math_u128::mul_div_round(liquidity, sqrt_price_b - sqrt_price_a, Q64);
        } else {
            amount_b = full_math_u128::mul_div_floor(liquidity, sqrt_price_b - sqrt_price_a, Q64);
        };

        amount_b
    }

    public fun get_amount_a_delta(
        sqrt_price_a: u128,
        sqrt_price_b: u128,
        liquidity: I128,
    ): I128 {
        if (i128::is_neg(liquidity)) {
            i128::neg_from(
                get_amount_a_delta_(
                    sqrt_price_a,
                    sqrt_price_b,
                    i128::as_u128(liquidity),
                    false
                )
            )
        } else {
            i128::from(
                get_amount_a_delta_(
                    sqrt_price_a,
                    sqrt_price_b,
                    i128::as_u128(liquidity),
                    true
                )
            )
        }
    }

    /// @notice Helper that gets signed token1 delta
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The change in liquidity for which to compute the amount1 delta
    /// @return amount1 Amount of token1 corresponding to the passed liquidityDelta between the two prices
    public fun get_amount_b_delta(
        sqrt_price_a: u128,
        sqrt_price_b: u128,
        liquidity: I128,
    ): I128 {
        if (i128::is_neg(liquidity)) {
            i128::neg_from(
                get_amount_b_delta_(
                    sqrt_price_a,
                    sqrt_price_b,
                    i128::as_u128(liquidity),
                    false
                )
            )
        } else {
            i128::from(
                get_amount_b_delta_(
                    sqrt_price_a,
                    sqrt_price_b,
                    i128::as_u128(liquidity),
                    true
                )
            )
        }
    }
}
