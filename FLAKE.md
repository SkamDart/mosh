# Mosh Nix Flake

This flake provides a Nix package for building Mosh using the Zig build system instead of autotools.

## Features

- ✅ Builds Mosh with Zig 0.15.1
- ✅ All dependencies managed by Nix
- ✅ Cross-platform support (Linux, macOS)
- ✅ Development shell with all tools
- ✅ Unit tests integration
- ✅ Apps for direct execution

## Quick Start

### Build and Install

```bash
# Build the package
nix build

# Run mosh directly (without installing)
nix run

# Install to your profile
nix profile install

# Or add to NixOS/home-manager configuration
```

### Run Without Installing

```bash
# Run mosh wrapper script
nix run .#default

# Run mosh-client directly
nix run .#mosh-client

# Run mosh-server directly
nix run .#mosh-server
```

### Development

Enter a development shell with all dependencies:

```bash
nix develop
```

This provides:
- Zig compiler
- All build dependencies (protobuf, ncurses, OpenSSL, etc.)
- Development tools (clang-tools, gdb, tmux)

Inside the dev shell:

```bash
# Build everything
zig build

# Run tests
zig build test

# Build specific targets
zig build --help
```

## Package Structure

### Outputs

- **packages.default** / **packages.mosh-zig**: The main Mosh package
- **devShells.default**: Development environment
- **apps.default**: Mosh wrapper script (requires SSH)
- **apps.mosh-client**: Direct mosh-client binary
- **apps.mosh-server**: Direct mosh-server binary

### Architecture Support

- ✅ x86_64-linux
- ✅ aarch64-linux
- ✅ x86_64-darwin (macOS Intel)
- ✅ aarch64-darwin (macOS Apple Silicon)

## Using in Your Flake

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    mosh-zig.url = "github:yourusername/mosh?ref=build-it-with-zig";
  };

  outputs = { nixpkgs, mosh-zig, ... }: {
    # Use in NixOS configuration
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      modules = [
        {
          environment.systemPackages = [
            mosh-zig.packages.x86_64-linux.default
          ];
        }
      ];
    };

    # Or in home-manager
    homeConfigurations.yourusername = home-manager.lib.homeManagerConfiguration {
      modules = [
        {
          home.packages = [
            mosh-zig.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

## Build Options

The Zig build system supports several options:

```bash
# Use different crypto backend (default: openssl)
nix build --override-input crypto nettle

# Optimize for size/speed
zig build -Doptimize=ReleaseSmall  # Smallest binary
zig build -Doptimize=ReleaseFast   # Fastest runtime
zig build -Doptimize=ReleaseSafe   # Default, with safety checks
```

## Testing

Run the test suite:

```bash
# In nix develop shell
zig build test

# Or via nix build with checks enabled
nix build --check
```

The flake runs these tests automatically:
- ocb-aes: OCB-AES encryption tests
- encrypt-decrypt: Crypto layer tests
- nonce-incr: Network nonce uniqueness tests

## Differences from nixpkgs Mosh

| Feature | nixpkgs (autotools) | This Flake (Zig) |
|---------|---------------------|------------------|
| Build system | autoconf/automake | Zig |
| Build time | ~2-3 minutes | ~1-2 minutes |
| Dependencies | Many autotools deps | Zig + runtime deps |
| Cross-compilation | Complex | Native Zig support |
| Cache usage | Good | Excellent (incremental) |
| Test integration | make check | zig build test |

## Dependencies

### Build-time (nativeBuildInputs)
- zig: Compiler and build system
- pkg-config: Dependency discovery
- protobuf: Protocol buffer compiler
- perl: For mosh wrapper script
- makeWrapper: Wraps binaries with environment

### Runtime (buildInputs)
- zlib: Compression
- protobuf: Protocol buffer runtime
- ncurses: Terminal handling
- openssl: Cryptography (or nettle/Apple CommonCrypto)
- abseil-cpp: Protobuf dependency
- libutempter: Login records (Linux only)

## Troubleshooting

### Build fails with protobuf errors

Make sure protobuf files are generated:
```bash
nix develop
zig build protoc
zig build
```

### Mosh wrapper script not found

The mosh wrapper (`scripts/mosh.pl`) needs to be present. If building from a git worktree, ensure it's included.

### SSH not found

The mosh wrapper requires SSH. Make sure openssh is in your PATH:
```bash
nix run --impure  # Uses system PATH
# Or install openssh
nix profile install nixpkgs#openssh
```

## Contributing

The Zig build system is in `build.zig`. Key areas:

- `createCppModule()`: Creates C++ compilation modules
- `linkCryptoLibrary()`: Links crypto backend (OpenSSL/Nettle/Apple)
- `buildTests()`: Test executable configuration

See `build.zig` for the complete build configuration.

## License

Mosh is licensed under GPLv3+. This flake follows the same license.
