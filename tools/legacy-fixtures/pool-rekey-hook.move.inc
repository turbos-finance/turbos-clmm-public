
    // Explicit compatibility-state overlay, inserted only into a disposable copy.
    // Relocate one existing Position without changing its bytes or the pool state.
    #[test_only]
    public fun security_rekey_position_fixture<A, B, F>(
        pool: &mut Pool<A, B, F>, from: address, to: address,
        lower: I32, upper: I32, legacy_encoding: bool,
    ) {
        let source = get_position_key_fix(pool, from, lower, upper);
        let destination = if (legacy_encoding) get_position_key_old(to, lower, upper)
            else get_position_key(to, lower, upper);
        assert!(source != destination && !dof::exists_(&pool.id, destination), 8800);
        let record = dof::remove<std::string::String, Position>(&mut pool.id, source);
        let bytes = std::bcs::to_bytes(&record);
        dof::add<std::string::String, Position>(&mut pool.id, destination, record);
        assert!(bytes == std::bcs::to_bytes(dof::borrow<std::string::String, Position>(&pool.id, destination)), 8801);
    }
