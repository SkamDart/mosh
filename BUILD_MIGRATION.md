# Mosh Build System Migration Analysis

## Phase 1: Current Build System Analysis

### Project Structure
The Mosh project uses a traditional Autoconf/Automake build system with the following structure:

```
mosh/
├── configure.ac          # Main autoconf configuration
├── Makefile.am          # Top-level automake file
└── src/
    ├── crypto/          # Cryptography library
    ├── network/         # Network transport library
    ├── terminal/        # Terminal emulation library
    ├── statesync/       # State synchronization library
    ├── util/            # Utility library
    ├── protobufs/       # Protocol buffer definitions
    ├── frontend/        # Main executables (mosh-client, mosh-server)
    ├── examples/        # Example programs
    ├── tests/           # Test suite
    └── fuzz/            # Fuzzing tests
```

### Build Configuration Features
- **C++ Standard**: C++17 required (minimum)
- **Compiler Support**: gcc, g++, clang, clang++
- **Build Options**:
  - `--enable-client` (default: yes)
  - `--enable-server` (default: yes)
  - `--enable-examples` (default: no)
  - `--enable-hardening` (default: yes)
  - `--enable-compile-warnings` (various levels)
  - `--enable-fuzzing` (libfuzzer support)
  - `--enable-asan` (AddressSanitizer)
  - `--enable-syslog` (connection logging)
  - `--enable-static-*` options for static linking

### Compiler Flags
- **Warning Flags**: `-Wall`, `-Wextra`, `-pedantic`, `-Weffc++`
- **Hardening**: `-fstack-protector-all`, `-fPIE`, `-D_FORTIFY_SOURCE=2`
- **Misc**: `-fno-default-inline`, `-pipe`

## Phase 2: Dependencies and Build Targets

### External Dependencies

#### Required Dependencies
1. **Protocol Buffers** (protobuf)
   - Used for serialization
   - Requires `protoc` compiler
   - Library: `-lprotobuf`

2. **Terminal Info Library** (tinfo/ncurses)
   - Terminal capabilities
   - Libraries: `-ltinfo` or `-lncurses`

3. **Compression** (zlib)
   - Network compression
   - Library: `-lz`

4. **Cryptography** (one of):
   - OpenSSL (default): `-lcrypto`
   - Nettle: `-lnettle`
   - Apple Common Crypto (macOS)

#### Optional Dependencies
- **libutempter**: For utmp entries
- **libutil/libbsd**: For `forkpty()`
- **librt**: For `clock_gettime()`
- **syslog.h**: For connection logging

### Build Libraries (Static)
1. **libmoshcrypto.a**
   - Sources: `ae.h`, `ocb_*.cc`, `base64.cc`, `crypto.cc`, `prng.h`, `byteorder.h`

2. **libmoshnetwork.a**
   - Sources: `network.cc`, `transportfragment.cc`, `compressor.cc`
   - Various header files

3. **libmoshterminal.a**
   - Sources: `parser*.cc`, `terminal*.cc`
   - Terminal emulation functionality

4. **libmoshstatesync.a**
   - Sources: `completeterminal.cc`, `user.cc`

5. **libmoshutil.a**
   - Sources: `locale_utils.cc`, `swrite.cc`, `select.cc`, `timestamp.cc`, `pty_compat.cc`

6. **libmoshprotos.a**
   - Generated from: `userinput.proto`, `hostinput.proto`, `transportinstruction.proto`
   - Requires protoc compilation step

### Main Executables
1. **mosh-client**
   - Sources: `mosh-client.cc`, `stmclient.cc`, `terminaloverlay.cc`
   - Links all static libraries

2. **mosh-server**
   - Sources: `mosh-server.cc`
   - Links all static libraries

### Test Programs
- `ocb-aes`, `encrypt-decrypt`, `base64`, `nonce-incr`, `inpty`, `is-utf8-locale`
- Shell script tests in `src/tests/*.test`

### Example Programs (when enabled)
- `encrypt`, `decrypt`, `ntester`, `parse`, `termemu`, `benchmark`

### Platform-Specific Considerations
- **macOS**: May use Apple Common Crypto instead of OpenSSL
- **Linux**: Standard OpenSSL/Nettle support
- **BSD**: May require additional libraries for util functions
- **Windows**: Not directly supported (uses Unix-specific features)

### Build Order
1. Generate protobuf sources (`.proto` → `.pb.cc` + `.pb.h`)
2. Build static libraries in order:
   - `libmoshutil.a` (no internal deps)
   - `libmoshcrypto.a` (no internal deps)
   - `libmoshprotos.a` (generated sources)
   - `libmoshterminal.a` (depends on util)
   - `libmoshnetwork.a` (depends on crypto)
   - `libmoshstatesync.a` (depends on terminal, protos)
3. Build executables (link all libraries)

### Installation Paths
- Binaries: `$(prefix)/bin/`
- Man pages: `$(prefix)/share/man/`
- Bash completion: Configurable, defaults to `$(sysconfdir)/bash_completion.d`
- UFW profile: Optional installation

## Next Steps for Zig Build System
1. Create `build.zig` with proper module structure
2. Implement protobuf generation step
3. Define static library compilation steps
4. Configure system library detection and linking
5. Add platform-specific conditionals
6. Set up test runner
7. Configure installation targets
