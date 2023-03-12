// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::math_sqrt_price {
    use turbos_clmm::math_u128;
    use turbos_clmm::full_math_u128;
    use turbos_clmm::i128::{Self, I128};

    const EInvildSqrtPrice: u64 = 0;
    const ELiquidity: u64 = 1;
    const EDenominatorOverflow: u64 = 2;

    const RESOLUTION: u8 = 64;
    const Q64: u128 = 0x10000000000000000;
    const MAX_U64: u128 = 0xffffffffffffffff;

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

    /// @notice Gets the next sqrt price given an input amount of token0 or token1
    /// @dev Throws if price or liquidity are 0, or if the next price is out of bounds
    /// @param sqrt_price The starting price, i.e., before accounting for the input amount
    /// @param liquidity The amount of usable liquidity
    /// @param amountIn How much of token0, or token1, is being swapped in
    /// @param a_for_b Whether the amount in is token0 or token1
    /// @return sqrtQX96 The price after adding the input amount to token0 or token1
    public fun get_next_sqrt_price_from_input(
        sqrt_price: u128,
        liquidity: u128,
        amount_in: u128,
        a_for_b: bool
    ): u128 {
        assert!(sqrt_price > 0, EInvildSqrtPrice);
        assert!(liquidity > 0, ELiquidity);

        // round to make sure that we don't pass the target price
        if (a_for_b) {
            get_next_sqrt_price_from_amount_a_rounding_up(sqrt_price, liquidity, amount_in, false)
        } else {
            get_next_sqrt_price_from_amount_b_rounding_down(sqrt_price, liquidity, amount_in, false)
        }
    }

    /// @notice Gets the next sqrt price given an output amount of token0 or token1
    /// @dev Throws if price or liquidity are 0 or the next price is out of bounds
    /// @param sqrt_price The starting price before accounting for the output amount
    /// @param liquidity The amount of usable liquidity
    /// @param amount_out How much of token0, or token1, is being swapped out
    /// @param a_for_b Whether the amount out is token0 or token1
    /// @return sqrtQX96 The price after removing the output amount of token0 or token1
    public fun get_next_sqrt_price_from_output(
        sqrt_price: u128,
        liquidity: u128,
        amount_out: u128,
         a_for_b: bool
    ): u128 {
        assert!(sqrt_price > 0, EInvildSqrtPrice);
        assert!(liquidity > 0, ELiquidity);

        // round to make sure that we pass the target price
        if (a_for_b) {
            get_next_sqrt_price_from_amount_b_rounding_down(sqrt_price, liquidity, amount_out, false)
        } else {
            get_next_sqrt_price_from_amount_a_rounding_up(sqrt_price, liquidity, amount_out, false)
        }
    }

    /// @notice Gets the next sqrt price given a delta of token0
    /// @dev Always rounds up, because in the exact output case (increasing price) we need to move the price at least
    /// far enough to get the desired output amount, and in the exact input case (decreasing price) we need to move the
    /// price less in order to not send too much output.
    /// The most precise formula for this is liquidity * sqrt_price / (liquidity +- amount * sqrt_price),
    /// if this is impossible because of overflow, we calculate liquidity / (liquidity / sqrt_price +- amount).
    /// @param sqrt_price The starting price, i.e. before accounting for the token0 delta
    /// @param liquidity The amount of usable liquidity
    /// @param amount How much of token0 to add or remove from virtual reserves
    /// @param add Whether to add or remove the amount of token0
    /// @return The price after adding or removing amount, depending on add
    fun get_next_sqrt_price_from_amount_a_rounding_up(
        sqrt_price: u128,
        liquidity: u128,
        amount: u128,
        add: bool
    ): u128 {
        // we short circuit amount == 0 because the result is otherwise not guaranteed to equal the input price
        if (amount == 0) return sqrt_price;
        let numerator1 = liquidity << RESOLUTION;

        if (add) {
            let product = full_math_u128::mul_div_floor(amount, sqrt_price, amount);
            if (product == sqrt_price) {
                let denominator = numerator1 + product;
                if (denominator >= numerator1) {
                    return full_math_u128::mul_div_round(numerator1, sqrt_price, denominator)
                };
            };

            math_u128::checked_div_round(numerator1, (numerator1 / sqrt_price) + amount, true)
        } else {
            let product = full_math_u128::mul_div_floor(amount, sqrt_price, amount);
            // if the product overflows, we know the denominator underflows
            // in addition, we must check that the denominator does not underflow
            assert!(product == sqrt_price && numerator1 > product, EDenominatorOverflow);
            let denominator = numerator1 - product;

            full_math_u128::mul_div_round(numerator1, sqrt_price, denominator)
        }
    }

    /// @notice Gets the next sqrt price given a delta of token1
    /// @dev Always rounds down, because in the exact output case (decreasing price) we need to move the price at least
    /// far enough to get the desired output amount, and in the exact input case (increasing price) we need to move the
    /// price less in order to not send too much output.
    /// The formula we compute is within <1 wei of the lossless version: sqrt_price +- amount / liquidity
    /// @param sqrt_price The starting price, i.e., before accounting for the token1 delta
    /// @param liquidity The amount of usable liquidity
    /// @param amount How much of token1 to add, or remove, from virtual reserves
    /// @param add Whether to add, or remove, the amount of token1
    /// @return The price after adding or removing `amount`
    fun get_next_sqrt_price_from_amount_b_rounding_down(
        sqrt_price: u128,
        liquidity: u128,
        amount: u128,
        add: bool
    ): u128 {
        // if we're adding (subtracting), rounding down requires rounding the quotient down (up)
        // in both cases, avoid a mulDiv for most inputs
        if (add) {
            let quotient = if (amount <= MAX_U64) {
                (amount << RESOLUTION) / liquidity
            } else {
                full_math_u128::mul_div_floor(amount, Q64, liquidity)
            };
            sqrt_price + quotient
        } else {
            let quotient = if (amount <= MAX_U64) {
                math_u128::checked_div_round(amount << RESOLUTION, liquidity, true)
            } else {
                full_math_u128::mul_div_round(amount, Q64, liquidity)
            };

            assert!(sqrt_price > quotient, EInvildSqrtPrice);

            sqrt_price - quotient
        }
    }
}
