
    // Test-only constructor injected ONLY into the disposable version-test package.
    // It is absent from the repository production source and normal bytecode.
    #[test_only]
    public fun security_version_fixture(version: u64, ctx: &mut TxContext): Versioned {
        Versioned { id: object::new(ctx), version }
    }

