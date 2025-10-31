const std = @import("std");

const TestConfig = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    crypto_backend: []const u8,
    protoc_step: *std.Build.Step,
    libmoshcrypto: *std.Build.Step.Compile,
    libmoshutil: *std.Build.Step.Compile,
    libmoshnetwork: *std.Build.Step.Compile,
    libmoshprotos: *std.Build.Step.Compile,
};

// ====================
// Common Helper Functions
// ====================

/// Creates a standard C++ module for Mosh build targets
fn createCppModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
}

/// Adds standard Mosh include paths to an artifact
fn addStandardIncludes(artifact: *std.Build.Step.Compile, b: *std.Build) void {
    artifact.addIncludePath(b.path("src/include"));
    artifact.addIncludePath(b.path("."));
}

/// Standard C++ compiler flags used across all Mosh targets
const standard_cpp_flags = [_][]const u8{
    "-std=c++17",
    "-Wall",
    "-fPIC",
};

/// Hardcoded Homebrew paths for macOS dependencies
/// TODO: Detect these dynamically or make configurable
const protobuf_include_path = "-I/opt/homebrew/Cellar/protobuf/33.0/include";
const abseil_include_path = "-I/opt/homebrew/Cellar/abseil/20250814.1/include";

/// C++ flags with protobuf includes (for protobuf-dependent targets)
const cpp_flags_with_protobuf = [_][]const u8{
    "-std=c++17",
    "-Wall",
    "-fPIC",
    protobuf_include_path,
    abseil_include_path,
};

fn buildTests(config: TestConfig) void {
    const b = config.b;
    const target = config.target;
    const optimize = config.optimize;
    const crypto_backend = config.crypto_backend;
    const protoc_step = config.protoc_step;
    const libmoshcrypto = config.libmoshcrypto;
    const libmoshutil = config.libmoshutil;
    const libmoshnetwork = config.libmoshnetwork;
    const libmoshprotos = config.libmoshprotos;

    // Test step to run all tests
    const test_step = b.step("test", "Run all tests");

    // ocb-aes test
    const ocb_aes_test = b.addExecutable(.{
        .name = "ocb-aes",
        .root_module = createCppModule(b, target, optimize),
    });

    ocb_aes_test.addIncludePath(b.path("src/tests"));
    ocb_aes_test.addIncludePath(b.path("src/crypto"));
    ocb_aes_test.addIncludePath(b.path("src/util"));
    addStandardIncludes(ocb_aes_test, b);

    ocb_aes_test.addCSourceFiles(.{
        .files = &.{
            "src/tests/ocb-aes.cc",
            "src/tests/test_utils.cc",
        },
        .flags = &standard_cpp_flags,
    });

    ocb_aes_test.linkLibrary(libmoshcrypto);
    ocb_aes_test.linkLibrary(libmoshutil);
    if (std.mem.eql(u8, crypto_backend, "openssl")) {
        ocb_aes_test.linkSystemLibrary("crypto");
    } else if (std.mem.eql(u8, crypto_backend, "nettle")) {
        ocb_aes_test.linkSystemLibrary("nettle");
    }

    b.installArtifact(ocb_aes_test);

    const run_ocb_aes = b.addRunArtifact(ocb_aes_test);
    test_step.dependOn(&run_ocb_aes.step);

    // encrypt-decrypt test
    const encrypt_decrypt_test = b.addExecutable(.{
        .name = "encrypt-decrypt",
        .root_module = createCppModule(b, target, optimize),
    });

    encrypt_decrypt_test.addIncludePath(b.path("src/tests"));
    encrypt_decrypt_test.addIncludePath(b.path("src/crypto"));
    encrypt_decrypt_test.addIncludePath(b.path("src/util"));
    addStandardIncludes(encrypt_decrypt_test, b);

    encrypt_decrypt_test.addCSourceFiles(.{
        .files = &.{
            "src/tests/encrypt-decrypt.cc",
            "src/tests/test_utils.cc",
        },
        .flags = &standard_cpp_flags,
    });

    encrypt_decrypt_test.linkLibrary(libmoshcrypto);
    encrypt_decrypt_test.linkLibrary(libmoshutil);
    if (std.mem.eql(u8, crypto_backend, "openssl")) {
        encrypt_decrypt_test.linkSystemLibrary("crypto");
    } else if (std.mem.eql(u8, crypto_backend, "nettle")) {
        encrypt_decrypt_test.linkSystemLibrary("nettle");
    }

    b.installArtifact(encrypt_decrypt_test);

    const run_encrypt_decrypt = b.addRunArtifact(encrypt_decrypt_test);
    test_step.dependOn(&run_encrypt_decrypt.step);

    // nonce-incr test
    const nonce_incr_test = b.addExecutable(.{
        .name = "nonce-incr",
        .root_module = createCppModule(b, target, optimize),
    });

    nonce_incr_test.addIncludePath(b.path("src/tests"));
    nonce_incr_test.addIncludePath(b.path("src/network"));
    nonce_incr_test.addIncludePath(b.path("src/crypto"));
    nonce_incr_test.addIncludePath(b.path("src/protobufs"));
    nonce_incr_test.addIncludePath(b.path("src/util"));
    addStandardIncludes(nonce_incr_test, b);

    nonce_incr_test.addCSourceFiles(.{
        .files = &.{
            "src/tests/nonce-incr.cc",
        },
        .flags = &cpp_flags_with_protobuf,
    });

    nonce_incr_test.linkLibrary(libmoshnetwork);
    nonce_incr_test.linkLibrary(libmoshcrypto);
    nonce_incr_test.linkLibrary(libmoshutil);
    nonce_incr_test.linkLibrary(libmoshprotos);
    nonce_incr_test.linkSystemLibrary("protobuf");
    nonce_incr_test.linkSystemLibrary("z");
    if (std.mem.eql(u8, crypto_backend, "openssl")) {
        nonce_incr_test.linkSystemLibrary("crypto");
    } else if (std.mem.eql(u8, crypto_backend, "nettle")) {
        nonce_incr_test.linkSystemLibrary("nettle");
    }

    nonce_incr_test.step.dependOn(protoc_step);
    b.installArtifact(nonce_incr_test);

    const run_nonce_incr = b.addRunArtifact(nonce_incr_test);
    test_step.dependOn(&run_nonce_incr.step);

    // inpty helper
    const inpty = b.addExecutable(.{
        .name = "inpty",
        .root_module = createCppModule(b, target, optimize),
    });

    inpty.addIncludePath(b.path("src/tests"));
    inpty.addIncludePath(b.path("src/util"));
    addStandardIncludes(inpty, b);

    inpty.addCSourceFiles(.{
        .files = &.{
            "src/tests/inpty.cc",
        },
        .flags = &standard_cpp_flags,
    });

    inpty.linkLibrary(libmoshutil);
    inpty.linkSystemLibrary("util");

    b.installArtifact(inpty);

    // is-utf8-locale helper
    const is_utf8_locale = b.addExecutable(.{
        .name = "is-utf8-locale",
        .root_module = createCppModule(b, target, optimize),
    });

    is_utf8_locale.addIncludePath(b.path("src/tests"));
    is_utf8_locale.addIncludePath(b.path("src/util"));
    addStandardIncludes(is_utf8_locale, b);

    is_utf8_locale.addCSourceFiles(.{
        .files = &.{
            "src/tests/is-utf8-locale.cc",
        },
        .flags = &standard_cpp_flags,
    });

    is_utf8_locale.linkLibrary(libmoshutil);
    is_utf8_locale.linkSystemLibrary("util");

    b.installArtifact(is_utf8_locale);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const crypto_backend = b.option([]const u8, "crypto", "Crypto backend: openssl, nettle, or apple") orelse "openssl";
    const use_openssl_ocb = b.option(bool, "openssl-ocb", "Use OpenSSL's OCB implementation") orelse false;

    // ====================
    // libmoshutil - The simplest library with no internal dependencies
    // ====================
    const libmoshutil = b.addLibrary(.{
        .name = "moshutil",
        .linkage = .static,
        .root_module = createCppModule(b, target, optimize),
    });

    // Add include paths
    libmoshutil.addIncludePath(b.path("src/util"));
    addStandardIncludes(libmoshutil, b);

    // Add C++ source files
    libmoshutil.addCSourceFiles(.{
        .files = &.{
            "src/util/locale_utils.cc",
            "src/util/swrite.cc",
            "src/util/select.cc",
            "src/util/timestamp.cc",
            "src/util/pty_compat.cc",
        },
        .flags = &standard_cpp_flags,
    });

    b.installArtifact(libmoshutil);

    // ====================
    // libmoshcrypto - Crypto library (no internal dependencies)
    // ====================
    const libmoshcrypto = b.addLibrary(.{
        .name = "moshcrypto",
        .linkage = .static,
        .root_module = createCppModule(b, target, optimize),
    });

    // Add include paths
    libmoshcrypto.addIncludePath(b.path("src/crypto"));
    addStandardIncludes(libmoshcrypto, b);

    // Determine which OCB implementation to use
    const ocb_source = if (std.mem.eql(u8, crypto_backend, "openssl") and use_openssl_ocb)
        "src/crypto/ocb_openssl.cc"
    else
        "src/crypto/ocb_internal.cc";

    // Build flags based on crypto backend
    const crypto_flags = if (std.mem.eql(u8, crypto_backend, "openssl"))
        if (use_openssl_ocb)
            &[_][]const u8{ "-std=c++17", "-Wall", "-fPIC", "-DUSE_OPENSSL_AES=1", "-DUSE_AES_OCB_FROM_OPENSSL=1" }
        else
            &[_][]const u8{ "-std=c++17", "-Wall", "-fPIC", "-DUSE_OPENSSL_AES=1" }
    else if (std.mem.eql(u8, crypto_backend, "nettle"))
        &[_][]const u8{ "-std=c++17", "-Wall", "-fPIC", "-DUSE_NETTLE_AES=1" }
    else if (std.mem.eql(u8, crypto_backend, "apple"))
        &[_][]const u8{ "-std=c++17", "-Wall", "-fPIC", "-DUSE_APPLE_COMMON_CRYPTO_AES=1" }
    else
        &[_][]const u8{ "-std=c++17", "-Wall", "-fPIC" };

    // Add C++ source files
    libmoshcrypto.addCSourceFiles(.{
        .files = &.{
            "src/crypto/base64.cc",
            "src/crypto/crypto.cc",
            ocb_source,
        },
        .flags = crypto_flags,
    });

    // Link with appropriate crypto library
    if (std.mem.eql(u8, crypto_backend, "openssl")) {
        libmoshcrypto.linkSystemLibrary("crypto");
    } else if (std.mem.eql(u8, crypto_backend, "nettle")) {
        libmoshcrypto.linkSystemLibrary("nettle");
    }
    // Apple Common Crypto is part of the system, no explicit linking needed

    b.installArtifact(libmoshcrypto);

    // ====================
    // libmoshnetwork - Network library (depends on libmoshcrypto)
    // ====================
    const libmoshnetwork = b.addLibrary(.{
        .name = "moshnetwork",
        .linkage = .static,
        .root_module = createCppModule(b, target, optimize),
    });

    // Add include paths
    libmoshnetwork.addIncludePath(b.path("src/network"));
    libmoshnetwork.addIncludePath(b.path("src/crypto"));
    addStandardIncludes(libmoshnetwork, b);

    // Add C++ source files (excluding transportfragment.cc which needs protobufs)
    libmoshnetwork.addCSourceFiles(.{
        .files = &.{
            "src/network/network.cc",
            "src/network/compressor.cc",
            // Note: transportfragment.cc excluded - requires protobuf generation
        },
        .flags = &standard_cpp_flags,
    });

    // Link with zlib for compression
    libmoshnetwork.linkSystemLibrary("z");

    b.installArtifact(libmoshnetwork);

    // ====================
    // libmoshprotos - Generated protobuf library
    // ====================

    // First, create protobuf generation steps
    const proto_sources = [_][]const u8{
        "src/protobufs/userinput.proto",
        "src/protobufs/hostinput.proto",
        "src/protobufs/transportinstruction.proto",
    };

    // Create a step that generates all protobuf files
    const protoc_step = b.step("protoc", "Generate protobuf files");

    for (proto_sources) |proto_file| {
        // Generate protobuf files using protoc
        const protoc_cmd = b.addSystemCommand(&.{
            "protoc",
            "--cpp_out=src/protobufs",
            "-I",
            "src/protobufs",
            proto_file,
        });
        protoc_step.dependOn(&protoc_cmd.step);
    }

    // Create the protobuf library
    const libmoshprotos = b.addLibrary(.{
        .name = "moshprotos",
        .linkage = .static,
        .root_module = createCppModule(b, target, optimize),
    });

    // Add include paths
    libmoshprotos.addIncludePath(b.path("src/protobufs"));
    addStandardIncludes(libmoshprotos, b);

    // Add generated C++ source files (hardcoded for now)
    libmoshprotos.addCSourceFiles(.{
        .files = &.{
            "src/protobufs/userinput.pb.cc",
            "src/protobufs/hostinput.pb.cc",
            "src/protobufs/transportinstruction.pb.cc",
        },
        .flags = &.{
            "-std=c++17",
            "-Wall",
            "-fPIC",
            "-Wno-error", // Protobuf generated code may have warnings
        },
    });

    // Link with protobuf library
    libmoshprotos.linkSystemLibrary("protobuf");

    // Make sure protobuf generation happens before compilation
    libmoshprotos.step.dependOn(protoc_step);

    b.installArtifact(libmoshprotos);

    // Now update libmoshnetwork to include transportfragment.cc
    libmoshnetwork.addCSourceFiles(.{
        .files = &.{
            "src/network/transportfragment.cc",
        },
        .flags = &standard_cpp_flags,
    });

    // Add protobuf include path to network library
    libmoshnetwork.addIncludePath(b.path("src/protobufs"));

    // Make network library depend on protobuf generation
    libmoshnetwork.step.dependOn(protoc_step);

    // ====================
    // libmoshterminal - Terminal emulation library (depends on libmoshutil)
    // ====================
    const libmoshterminal = b.addLibrary(.{
        .name = "moshterminal",
        .linkage = .static,
        .root_module = createCppModule(b, target, optimize),
    });

    // Add include paths
    libmoshterminal.addIncludePath(b.path("src/terminal"));
    libmoshterminal.addIncludePath(b.path("src/util"));
    addStandardIncludes(libmoshterminal, b);

    // Add all terminal C++ source files
    libmoshterminal.addCSourceFiles(.{
        .files = &.{
            "src/terminal/parser.cc",
            "src/terminal/parseraction.cc",
            "src/terminal/parserstate.cc",
            "src/terminal/terminal.cc",
            "src/terminal/terminaldispatcher.cc",
            "src/terminal/terminaldisplay.cc",
            "src/terminal/terminaldisplayinit.cc",
            "src/terminal/terminalframebuffer.cc",
            "src/terminal/terminalfunctions.cc",
            "src/terminal/terminaluserinput.cc",
        },
        .flags = &standard_cpp_flags,
    });

    // Link with ncurses/tinfo for terminal capabilities
    // Try ncurses first, fall back to tinfo
    libmoshterminal.linkSystemLibrary("ncurses");

    b.installArtifact(libmoshterminal);

    // ====================
    // libmoshstatesync - State synchronization library (depends on libmoshterminal + libmoshprotos)
    // ====================
    const libmoshstatesync = b.addLibrary(.{
        .name = "moshstatesync",
        .linkage = .static,
        .root_module = createCppModule(b, target, optimize),
    });

    // Add include paths
    libmoshstatesync.addIncludePath(b.path("src/statesync"));
    libmoshstatesync.addIncludePath(b.path("src/terminal"));
    libmoshstatesync.addIncludePath(b.path("src/protobufs"));
    libmoshstatesync.addIncludePath(b.path("src/util"));
    addStandardIncludes(libmoshstatesync, b);

    // Add statesync C++ source files
    libmoshstatesync.addCSourceFiles(.{
        .files = &.{
            "src/statesync/completeterminal.cc",
            "src/statesync/user.cc",
        },
        .flags = &cpp_flags_with_protobuf,
    });

    // Link with protobuf library (since it uses protobufs)
    libmoshstatesync.linkSystemLibrary("protobuf");

    // Make sure it depends on protobuf generation (since it uses protobufs)
    libmoshstatesync.step.dependOn(protoc_step);

    b.installArtifact(libmoshstatesync);

    // ====================
    // mosh-client - Main client executable
    // ====================
    const mosh_client = b.addExecutable(.{
        .name = "mosh-client",
        .root_module = createCppModule(b, target, optimize),
    });

    // Add include paths
    mosh_client.addIncludePath(b.path("src/frontend"));
    mosh_client.addIncludePath(b.path("src/statesync"));
    mosh_client.addIncludePath(b.path("src/terminal"));
    mosh_client.addIncludePath(b.path("src/network"));
    mosh_client.addIncludePath(b.path("src/crypto"));
    mosh_client.addIncludePath(b.path("src/protobufs"));
    mosh_client.addIncludePath(b.path("src/util"));
    addStandardIncludes(mosh_client, b);

    // Add mosh-client source files
    mosh_client.addCSourceFiles(.{
        .files = &.{
            "src/frontend/mosh-client.cc",
            "src/frontend/stmclient.cc",
            "src/frontend/terminaloverlay.cc",
        },
        .flags = &cpp_flags_with_protobuf,
    });

    // Link with all the static libraries we built
    mosh_client.linkLibrary(libmoshcrypto);
    mosh_client.linkLibrary(libmoshnetwork);
    mosh_client.linkLibrary(libmoshstatesync);
    mosh_client.linkLibrary(libmoshterminal);
    mosh_client.linkLibrary(libmoshutil);
    mosh_client.linkLibrary(libmoshprotos);

    // Link with system libraries
    mosh_client.linkSystemLibrary("ncurses");
    mosh_client.linkSystemLibrary("protobuf");
    mosh_client.linkSystemLibrary("z");
    if (std.mem.eql(u8, crypto_backend, "openssl")) {
        mosh_client.linkSystemLibrary("crypto");
    } else if (std.mem.eql(u8, crypto_backend, "nettle")) {
        mosh_client.linkSystemLibrary("nettle");
    }

    // Link with math library
    mosh_client.linkSystemLibrary("m");

    // Make sure protobuf generation happens before building
    mosh_client.step.dependOn(protoc_step);

    b.installArtifact(mosh_client);

    // ====================
    // mosh-server - Main server executable
    // ====================
    const mosh_server = b.addExecutable(.{
        .name = "mosh-server",
        .root_module = createCppModule(b, target, optimize),
    });

    // Add include paths
    mosh_server.addIncludePath(b.path("src/frontend"));
    mosh_server.addIncludePath(b.path("src/statesync"));
    mosh_server.addIncludePath(b.path("src/terminal"));
    mosh_server.addIncludePath(b.path("src/network"));
    mosh_server.addIncludePath(b.path("src/crypto"));
    mosh_server.addIncludePath(b.path("src/protobufs"));
    mosh_server.addIncludePath(b.path("src/util"));
    addStandardIncludes(mosh_server, b);

    // Add mosh-server source file (just one!)
    mosh_server.addCSourceFiles(.{
        .files = &.{
            "src/frontend/mosh-server.cc",
        },
        .flags = &.{
            "-std=c++17",
            "-Wall",
            "-fPIC",
            "-Wno-deprecated-declarations", // Suppress shared_ptr::unique() deprecation warning
            protobuf_include_path,
            abseil_include_path,
        },
    });

    // Link with all the static libraries we built
    mosh_server.linkLibrary(libmoshcrypto);
    mosh_server.linkLibrary(libmoshnetwork);
    mosh_server.linkLibrary(libmoshstatesync);
    mosh_server.linkLibrary(libmoshterminal);
    mosh_server.linkLibrary(libmoshutil);
    mosh_server.linkLibrary(libmoshprotos);

    // Link with system libraries
    mosh_server.linkSystemLibrary("ncurses");
    mosh_server.linkSystemLibrary("protobuf");
    mosh_server.linkSystemLibrary("z");
    if (std.mem.eql(u8, crypto_backend, "openssl")) {
        mosh_server.linkSystemLibrary("crypto");
    } else if (std.mem.eql(u8, crypto_backend, "nettle")) {
        mosh_server.linkSystemLibrary("nettle");
    }

    // Link with math library
    mosh_server.linkSystemLibrary("m");

    // Link with util library for forkpty() on macOS and other platforms
    mosh_server.linkSystemLibrary("util");

    // Make sure protobuf generation happens before building
    mosh_server.step.dependOn(protoc_step);

    b.installArtifact(mosh_server);

    // ====================
    // Tests
    // ====================
    buildTests(.{
        .b = b,
        .target = target,
        .optimize = optimize,
        .crypto_backend = crypto_backend,
        .protoc_step = protoc_step,
        .libmoshcrypto = libmoshcrypto,
        .libmoshutil = libmoshutil,
        .libmoshnetwork = libmoshnetwork,
        .libmoshprotos = libmoshprotos,
    });

    // Add a build step to show what was built
    const info_step = b.step("info", "Show build information");
    const info_cmd = b.addSystemCommand(&.{
        "echo",
        b.fmt("Built libraries:\n- libmoshutil.a\n- libmoshcrypto.a (backend: {s})\n- libmoshnetwork.a (complete)\n- libmoshprotos.a\n- libmoshterminal.a\n- libmoshstatesync.a\n\nExecutables:\n- mosh-client\n- mosh-server\n\nFull build complete! 🎉\n", .{crypto_backend}),
    });
    info_step.dependOn(&info_cmd.step);
}
