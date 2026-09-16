{
  description = "StreamFuzz — coverage-guided StreamData development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        # OTP 27 +:cover has lower overhead when native coverage is available.
        # Bump elixir_* here when nixpkgs adds newer matching releases.
        beamPkgs = pkgs.beam.packages.erlang_27;
        elixir = beamPkgs.elixir_1_18 or beamPkgs.elixir;

        fileWatcher =
          if pkgs.stdenv.isDarwin then
            [ pkgs.fswatch ]
          else
            [ pkgs.inotify-tools ];
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.mkShell {
          name = "stream-fuzz";

          packages = [
            elixir
            beamPkgs.erlang
            beamPkgs.rebar3
            pkgs.git
            pkgs.gnumake
          ]
          ++ fileWatcher;

          shellHook = ''
            export MIX_HOME="$PWD/.mix"
            export HEX_HOME="$PWD/.hex"
            mkdir -p "$MIX_HOME" "$HEX_HOME"

            # Keep BEAM crash dumps and build artifacts inside the repo.
            export ERL_CRASH_DUMP="$PWD/erllib_crash.dump"
            export ERL_AFLAGS="-kernel shell_history enabled"

            echo "StreamFuzz dev shell"
            echo "  Erlang  $(erl -eval 'io:format("~s~n", [erlang:system_info(otp_release)]), halt().' -noshell 2>/dev/null || echo '?')"
            echo "  Elixir  $(elixir --short-version 2>/dev/null || echo '?')"
            echo "  Design  DESIGN-hypofuzz-stream-data.md"
            echo "  Next    mix test && mix stream_fuzz --max-examples 100"
          '';
        };
      }
    );
}
