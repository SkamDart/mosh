{
  description = "Mosh (mobile shell) - built with Zig build system";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        mosh-zig = pkgs.stdenv.mkDerivation {
          pname = "mosh-zig";
          version = "1.4.0-zig";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            zig
            pkg-config
            protobuf
            perl
            makeWrapper
          ];

          buildInputs = with pkgs; [
            zlib
            protobuf
            ncurses
            openssl
            abseil-cpp
          ] ++ lib.optionals stdenv.hostPlatform.isLinux [
            libutempter
          ];

          # Generate protobuf files before building
          preBuild = ''
            zig build protoc
          '';

          buildPhase = ''
            runHook preBuild

            # Build with Zig
            zig build -Doptimize=ReleaseSafe --prefix $out

            runHook postBuild
          '';

          # Note: Zig build handles installation via --prefix
          installPhase = ''
            runHook preInstall

            # Already installed by zig build, but ensure scripts are in place
            # Copy mosh wrapper script if it exists
            if [ -f scripts/mosh.pl ]; then
              install -Dm755 scripts/mosh.pl $out/bin/mosh
            fi

            runHook postInstall
          '';

          postInstall = ''
            # Wrap the mosh script to find mosh-client and ssh
            if [ -f $out/bin/mosh ]; then
              wrapProgram $out/bin/mosh \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.openssh ]} \
                --set MOSH_CLIENT_PATH "$out/bin/mosh-client"
            fi
          '';

          # Run tests
          doCheck = true;
          checkPhase = ''
            runHook preCheck

            # Run Zig-built unit tests
            zig build test

            runHook postCheck
          '';

          meta = with pkgs.lib; {
            homepage = "https://mosh.org/";
            description = "Mobile shell (ssh replacement) - Zig build";
            longDescription = ''
              Remote terminal application that allows roaming, supports intermittent
              connectivity, and provides intelligent local echo and line editing of
              user keystrokes.

              Mosh is a replacement for SSH. It's more robust and responsive,
              especially over Wi-Fi, cellular, and long-distance links.

              This version is built using the Zig build system instead of autotools.
            '';
            license = licenses.gpl3Plus;
            maintainers = with maintainers; [ skeuchel ];
            platforms = platforms.unix;
            mainProgram = "mosh";
          };
        };

      in
      {
        packages = {
          default = mosh-zig;
          mosh-zig = mosh-zig;
        };

        # Development shell with all dependencies
        devShells.default = pkgs.mkShell {
          inputsFrom = [ mosh-zig ];
          packages = with pkgs; [
            # Additional development tools
            clang-tools
            gdb
            tmux # For running e2e tests
          ];

          shellHook = ''
            echo "Mosh Zig build environment"
            echo "Available commands:"
            echo "  zig build          - Build all targets"
            echo "  zig build test     - Run unit tests"
            echo "  zig build -h       - Show all build options"
          '';
        };

        # Apps that can be run with 'nix run'
        apps = {
          default = {
            type = "app";
            program = "${mosh-zig}/bin/mosh";
          };
          mosh-client = {
            type = "app";
            program = "${mosh-zig}/bin/mosh-client";
          };
          mosh-server = {
            type = "app";
            program = "${mosh-zig}/bin/mosh-server";
          };
        };
      }
    );
}
