const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const crypto_backend = b.option([]const u8, "crypto", "Crypto backend: openssl, nettle, or apple") orelse "openssl";
    const use_openssl_ocb = b.option(bool, "openssl-ocb", "Use OpenSSL's OCB implementation") orelse false;

    // ====================
    // libmoshutil - The simplest library with no internal dependencies
    // ====================
    const util_module = b.createModule(.{
        .root_source_file = null, // No Zig source
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const libmoshutil = b.addLibrary(.{
        .name = "moshutil",
        .linkage = .static,
        .root_module = util_module,
    });

    // Add include paths
    libmoshutil.addIncludePath(b.path("src/util"));
    libmoshutil.addIncludePath(b.path("src/include"));
    libmoshutil.addIncludePath(b.path("."));

    // Add C++ source files
    libmoshutil.addCSourceFiles(.{
        .files = &.{
            "src/util/locale_utils.cc",
            "src/util/swrite.cc",
            "src/util/select.cc",
            "src/util/timestamp.cc",
            "src/util/pty_compat.cc",
        },
        .flags = &.{
            "-std=c++17",
            "-Wall",
            "-fPIC",
        },
    });

    b.installArtifact(libmoshutil);

    // ====================
    // libmoshcrypto - Crypto library (no internal dependencies)
    // ====================
    const crypto_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const libmoshcrypto = b.addLibrary(.{
        .name = "moshcrypto",
        .linkage = .static,
        .root_module = crypto_module,
    });

    // Add include paths
    libmoshcrypto.addIncludePath(b.path("src/crypto"));
    libmoshcrypto.addIncludePath(b.path("src/include"));
    libmoshcrypto.addIncludePath(b.path("."));

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
    const network_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const libmoshnetwork = b.addLibrary(.{
        .name = "moshnetwork",
        .linkage = .static,
        .root_module = network_module,
    });

    // Add include paths
    libmoshnetwork.addIncludePath(b.path("src/network"));
    libmoshnetwork.addIncludePath(b.path("src/crypto"));
    libmoshnetwork.addIncludePath(b.path("src/include"));
    libmoshnetwork.addIncludePath(b.path("."));

    // Add C++ source files (excluding transportfragment.cc which needs protobufs)
    libmoshnetwork.addCSourceFiles(.{
        .files = &.{
            "src/network/network.cc",
            "src/network/compressor.cc",
            // Note: transportfragment.cc excluded - requires protobuf generation
        },
        .flags = &.{
            "-std=c++17",
            "-Wall",
            "-fPIC",
        },
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
    const protos_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const libmoshprotos = b.addLibrary(.{
        .name = "moshprotos",
        .linkage = .static,
        .root_module = protos_module,
    });

    // Add include paths
    libmoshprotos.addIncludePath(b.path("src/protobufs"));
    libmoshprotos.addIncludePath(b.path("src/include"));
    libmoshprotos.addIncludePath(b.path("."));

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
        .flags = &.{
            "-std=c++17",
            "-Wall",
            "-fPIC",
        },
    });

    // Add protobuf include path to network library
    libmoshnetwork.addIncludePath(b.path("src/protobufs"));

    // Make network library depend on protobuf generation
    libmoshnetwork.step.dependOn(protoc_step);

    // ====================
    // libmoshterminal - Terminal emulation library (depends on libmoshutil)
    // ====================
    const terminal_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const libmoshterminal = b.addLibrary(.{
        .name = "moshterminal",
        .linkage = .static,
        .root_module = terminal_module,
    });

    // Add include paths
    libmoshterminal.addIncludePath(b.path("src/terminal"));
    libmoshterminal.addIncludePath(b.path("src/util"));
    libmoshterminal.addIncludePath(b.path("src/include"));
    libmoshterminal.addIncludePath(b.path("."));

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
        .flags = &.{
            "-std=c++17",
            "-Wall",
            "-fPIC",
        },
    });

    // Link with ncurses/tinfo for terminal capabilities
    // Try ncurses first, fall back to tinfo
    libmoshterminal.linkSystemLibrary("ncurses");

    b.installArtifact(libmoshterminal);

    // ====================
    // libmoshstatesync - State synchronization library (depends on libmoshterminal + libmoshprotos)
    // ====================
    const statesync_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const libmoshstatesync = b.addLibrary(.{
        .name = "moshstatesync",
        .linkage = .static,
        .root_module = statesync_module,
    });

    // Add include paths
    libmoshstatesync.addIncludePath(b.path("src/statesync"));
    libmoshstatesync.addIncludePath(b.path("src/terminal"));
    libmoshstatesync.addIncludePath(b.path("src/protobufs"));
    libmoshstatesync.addIncludePath(b.path("src/util"));
    libmoshstatesync.addIncludePath(b.path("src/include"));
    libmoshstatesync.addIncludePath(b.path("."));

    // Add statesync C++ source files
    libmoshstatesync.addCSourceFiles(.{
        .files = &.{
            "src/statesync/completeterminal.cc",
            "src/statesync/user.cc",
        },
        .flags = &.{
            "-std=c++17",
            "-Wall",
            "-fPIC",
            "-I/opt/homebrew/Cellar/protobuf/33.0/include",
            "-I/opt/homebrew/Cellar/abseil/20250814.1/include",
        },
    });

    // Link with protobuf library (since it uses protobufs)
    libmoshstatesync.linkSystemLibrary("protobuf");

    // Make sure it depends on protobuf generation (since it uses protobufs)
    libmoshstatesync.step.dependOn(protoc_step);

    b.installArtifact(libmoshstatesync);

    // ====================
    // mosh-client - Main client executable
    // ====================
    const mosh_client_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const mosh_client = b.addExecutable(.{
        .name = "mosh-client",
        .root_module = mosh_client_module,
    });

    // Add include paths
    mosh_client.addIncludePath(b.path("src/frontend"));
    mosh_client.addIncludePath(b.path("src/statesync"));
    mosh_client.addIncludePath(b.path("src/terminal"));
    mosh_client.addIncludePath(b.path("src/network"));
    mosh_client.addIncludePath(b.path("src/crypto"));
    mosh_client.addIncludePath(b.path("src/protobufs"));
    mosh_client.addIncludePath(b.path("src/util"));
    mosh_client.addIncludePath(b.path("src/include"));
    mosh_client.addIncludePath(b.path("."));

    // Add mosh-client source files
    mosh_client.addCSourceFiles(.{
        .files = &.{
            "src/frontend/mosh-client.cc",
            "src/frontend/stmclient.cc",
            "src/frontend/terminaloverlay.cc",
        },
        .flags = &.{
            "-std=c++17",
            "-Wall",
            "-fPIC",
            "-I/opt/homebrew/Cellar/protobuf/33.0/include",
            "-I/opt/homebrew/Cellar/abseil/20250814.1/include",
        },
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
    const mosh_server_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const mosh_server = b.addExecutable(.{
        .name = "mosh-server",
        .root_module = mosh_server_module,
    });

    // Add include paths
    mosh_server.addIncludePath(b.path("src/frontend"));
    mosh_server.addIncludePath(b.path("src/statesync"));
    mosh_server.addIncludePath(b.path("src/terminal"));
    mosh_server.addIncludePath(b.path("src/network"));
    mosh_server.addIncludePath(b.path("src/crypto"));
    mosh_server.addIncludePath(b.path("src/protobufs"));
    mosh_server.addIncludePath(b.path("src/util"));
    mosh_server.addIncludePath(b.path("src/include"));
    mosh_server.addIncludePath(b.path("."));

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
            "-I/opt/homebrew/Cellar/protobuf/33.0/include",
            "-I/opt/homebrew/Cellar/abseil/20250814.1/include",
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

    // Add a build step to show what was built
    const info_step = b.step("info", "Show build information");
    const info_cmd = b.addSystemCommand(&.{
        "echo",
        b.fmt("Built libraries:\n- libmoshutil.a\n- libmoshcrypto.a (backend: {s})\n- libmoshnetwork.a (complete)\n- libmoshprotos.a\n- libmoshterminal.a\n- libmoshstatesync.a\n\nExecutables:\n- mosh-client\n- mosh-server\n\nFull build complete! 🎉\n", .{crypto_backend}),
    });
    info_step.dependOn(&info_cmd.step);
}
