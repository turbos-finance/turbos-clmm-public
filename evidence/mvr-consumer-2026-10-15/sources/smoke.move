module consumer::smoke { use turbos_clmm::full_math_u64; public fun quote(a: u64,b: u64,d: u64): u64 { full_math_u64::mul_div_floor(a,b,d) } }
