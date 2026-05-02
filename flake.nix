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

        cogcast-q0 = pkgs.callPackage ./host/cogcast-q0/nix/package.nix { };

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

        firmware-cogcast = qmkNixLib.mkFirmware {
          name    = "firmware-cogcast";
          plugins = [ ];
          cogcast = true;
        };

        flash-cogcast = qmkNixLib.mkFlashScript {
          firmware = firmware-cogcast;
          name     = "flash-cogcast";
        };

        firmware-cogcast-illustrator = qmkNixLib.mkFirmware {
          name    = "firmware-cogcast-illustrator";
          plugins = [ "illustrator" ];
          cogcast = true;
        };

        flash-cogcast-illustrator = qmkNixLib.mkFlashScript {
          firmware = firmware-cogcast-illustrator;
          name     = "flash-cogcast-illustrator";
        };
      in {
        packages = {
          default = qmk-nix-codegen;
          inherit qmk-nix-codegen
                  cogcast-q0
                  firmware-illustrator
                  firmware-cogcast
                  firmware-cogcast-illustrator;
        };

        apps.flash-illustrator = {
          type = "app";
          program = "${flash-illustrator}/bin/flash-illustrator";
        };

        apps.flash-cogcast = {
          type = "app";
          program = "${flash-cogcast}/bin/flash-cogcast";
        };

        apps.flash-cogcast-illustrator = {
          type = "app";
          program = "${flash-cogcast-illustrator}/bin/flash-cogcast-illustrator";
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
      }) // {
        # home-manager module for the cogcast-q0 host bridge daemon.
        homeManagerModules.cogcast-q0 = import ./nix/home-manager-cogcast-q0.nix self;
        homeManagerModules.default    = import ./nix/home-manager-cogcast-q0.nix self;
      };
}
