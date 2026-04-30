{
  description = "qmk-nix: declarative QMK firmware + macOS layer-switching for Keychron Q0 Max";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    qmk-firmware-keychron = {
      # Pinned to the 2025q3 branch (Q0 Max is on the Keychron fork only —
      # not upstream qmk_firmware). submodules=1 pulls ChibiOS / lufa / vusb.
      url = "git+https://github.com/Keychron/qmk_firmware?ref=2025q3&submodules=1";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, qmk-firmware-keychron }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        haskellPkgs = pkgs.haskellPackages;
        qmk-nix-codegen = haskellPkgs.callCabal2nix "qmk-nix" ./. { };

        qmkNixLib = import ./nix/lib.nix {
          inherit pkgs qmk-nix-codegen;
          qmk-firmware-src = qmk-firmware-keychron;
          firmware-stub    = ./firmware-stub;
        };

        firmware-illustrator = qmkNixLib.mkFirmware {
          name    = "firmware-illustrator";
          plugins = [ "illustrator" ];
        };

        flash-illustrator = qmkNixLib.mkFlashScript {
          firmware = firmware-illustrator;
          name     = "flash-illustrator";
        };
      in {
        packages = {
          default = qmk-nix-codegen;
          inherit qmk-nix-codegen firmware-illustrator;
        };

        apps.flash-illustrator = {
          type = "app";
          program = "${flash-illustrator}/bin/flash-illustrator";
        };

        devShells.default = haskellPkgs.shellFor {
          packages = _: [ qmk-nix-codegen ];
          nativeBuildInputs = [
            pkgs.cabal-install
            haskellPkgs.haskell-language-server
            haskellPkgs.cabal-fmt
            pkgs.qmk
            pkgs.dfu-util
          ];
        };

        # Per-system lib for downstream consumers (e.g. nixvana) wanting to
        # compose their own plugin set: `qmk-nix.lib.${system}.mkFirmware { plugins = [...]; }`.
        lib = qmkNixLib;
      });
}
