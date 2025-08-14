{
  description = "Mosh: the mobile shell - built with Zig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        mosh-zig = pkgs.stdenv.mkDerivation rec {
          pname = "mosh";
          version = "1.4.0";
          
          src = ./.;
          
          nativeBuildInputs = with pkgs; [
            zig
            autoconf
            automake
            pkg-config
            protobuf
            perl
          ];
          
          buildInputs = with pkgs; [
            ncurses
            protobuf
            openssl
            zlib
          ];
          
          # Configure Zig as the C/C++ compiler
          preConfigure = ''
            export CC="zig cc"
            export CXX="zig c++"
            export AR="zig ar"
            export RANLIB="zig ranlib"
            
            # Run autogen.sh to generate configure script
            ./autogen.sh
          '';
          
          configureFlags = [
            "--enable-compile-warnings=no"  # Disable warnings for cleaner build
            "--with-crypto-library=openssl"
          ];
          
          # Zig sometimes needs these flags for C++ compatibility
          NIX_CFLAGS_COMPILE = "-std=c++17";
          
          enableParallelBuilding = true;
          
          meta = with pkgs.lib; {
            description = "Mobile shell (mosh) built with Zig";
            homepage = "https://mosh.org/";
            license = licenses.gpl3Plus;
            platforms = platforms.unix;
          };
        };
      in
      {
        packages = {
          default = mosh-zig;
          mosh = mosh-zig;
        };
        
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
            autoconf
            automake
            pkg-config
            protobuf
            perl
            ncurses
            openssl
            zlib
            # Development tools
            gdb
            valgrind
            clang-tools
          ];
          
          shellHook = ''
            echo "Mosh development environment with Zig"
            echo "Use 'nix build' to build mosh with Zig"
            echo ""
            echo "Manual build steps:"
            echo "  1. ./autogen.sh"
            echo "  2. CC='zig cc' CXX='zig c++' ./configure"
            echo "  3. make"
          '';
        };
      });
}