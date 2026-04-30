{ pkgs, qmk-nix-codegen, qmk-firmware-src, firmware-stub }:

let
  lib = pkgs.lib;

  keymapName = "qmknix";

  # Build a Q0 Max firmware .bin against the pinned Keychron QMK fork, with
  # the chosen plugins compiled into the keymap.
  mkFirmware = { name ? "q0-max-firmware", plugins }:
    pkgs.stdenv.mkDerivation {
      pname = name;
      version = "0.1.0";

      # The firmware-stub directory is the derivation src so its .c files land
      # at $src and can be copied into the keymap dir.
      src = firmware-stub;

      nativeBuildInputs = [ pkgs.qmk qmk-nix-codegen ];

      dontConfigure = true;

      buildPhase = ''
        runHook preBuild
        set -eu

        # Strip nix wrapper-injected flags that conflict with arm-none-eabi-gcc.
        # (Per EdenEast's qmk flake; see README "Caveats" for context.)
        export NIX_CFLAGS_COMPILE=""
        export NIX_CFLAGS_LINK=""

        export HOME=$PWD/.fake-home
        mkdir -p "$HOME"

        # Stage the QMK tree as a writable copy (qmk CLI writes intermediate
        # build files; the /nix/store source is read-only).
        cp -r ${qmk-firmware-src} ./qmk
        chmod -R u+w ./qmk

        # Make Keychron's raw_hid_receive weakly linked so our keymap's strong
        # definition takes precedence at link time. (The Keychron fork hardcodes
        # a strong dispatcher in keychron_common/keychron_raw_hid.c; without VIA
        # there's no clean user-hook to extend it, so this minimal weak-attr
        # patch is the smallest viable change.)
        KCRH=qmk/keyboards/keychron/common/keychron_raw_hid.c
        sed 's|^void raw_hid_receive(uint8_t src|__attribute__((weak)) void raw_hid_receive(uint8_t src|' \
            "$KCRH" > "$KCRH.new"
        mv "$KCRH.new" "$KCRH"
        grep -q '__attribute__((weak)) void raw_hid_receive' "$KCRH" \
          || { echo "ERROR: weak-attr patch did not apply to $KCRH" >&2; exit 1; }

        # Generate keymap.c / layers.h / rules.mk / init.lua into a side dir.
        GENERATED="$PWD/generated"
        mkdir -p "$GENERATED"
        ${qmk-nix-codegen}/bin/qmk-nix-codegen gen \
          ${lib.concatMapStringsSep " " (p: "--plugin ${lib.escapeShellArg p}") plugins} \
          --out "$GENERATED"

        # Drop the firmware-relevant files plus static support files in-tree.
        # In-tree placement avoids quirks with qmk's user.overlay_dir mechanism
        # in 1.2.0 (which silently drops keymap names with hyphens).
        KEYMAP_DIR="$PWD/qmk/keyboards/keychron/q0_max/encoder/keymaps/${keymapName}"
        mkdir -p "$KEYMAP_DIR"
        cp "$GENERATED/keymap.c"          "$KEYMAP_DIR/keymap.c"
        cp "$GENERATED/qmk_nix_layers.h"  "$KEYMAP_DIR/qmk_nix_layers.h"
        cp "$GENERATED/rules.mk"          "$KEYMAP_DIR/rules.mk"
        cp "$src/config.h"                    "$KEYMAP_DIR/config.h"
        cp "$src/qmk_nix_raw_hid.c"           "$KEYMAP_DIR/qmk_nix_raw_hid.c"
        cp "$src/qmk_nix_indicators.c"        "$KEYMAP_DIR/qmk_nix_indicators.c"
        cp "$src/qmk_nix_wireless_fallback.c" "$KEYMAP_DIR/qmk_nix_wireless_fallback.c"

        export QMK_HOME="$PWD/qmk"
        cd qmk

        SKIP_VERSION=yes SKIP_GIT=yes \
          ${pkgs.qmk}/bin/qmk compile \
            -kb keychron/q0_max/encoder \
            -km ${keymapName} \
            -j 1

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out

        BIN=$(find . -maxdepth 2 -name '*.bin' -print -quit || true)
        if [ -z "$BIN" ]; then
          echo "ERROR: no .bin produced; check the qmk compile output above" >&2
          exit 1
        fi
        cp "$BIN" $out/q0-max.bin

        # Stash the Hammerspoon init.lua alongside; the home-manager module
        # (next phase) consumes this.
        cp ../generated/init.lua $out/init.lua

        runHook postInstall
      '';

      meta = {
        description = "Custom QMK firmware for Keychron Q0 Max with qmk-nix plugins: ${lib.concatStringsSep ", " plugins}";
        platforms = lib.platforms.linux ++ lib.platforms.darwin;
      };
    };

  # `nix run .#flash-<plugin-set>` walks the user through DFU mode and flashes.
  mkFlashScript = { firmware, name ? "flash-q0-max" }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.dfu-util ];
      text = ''
        FIRMWARE="${firmware}/q0-max.bin"

        cat <<'EOF'
====================================================================
Put your Q0 Max into DFU (bootloader) mode:

  1. Set the mode switch on the back of the keyboard to "Cable".
  2. Unplug the USB cable.
  3. Hold down the Esc key (top row, second from left — directly
     to the right of the rotary encoder).
  4. While still holding Esc, plug the cable back in.
  5. Release Esc after about 2 seconds.

The keyboard's lights will be off in DFU mode (no LED activity).

Press Enter once you've done this...
====================================================================
EOF
        read -r _ </dev/tty

        if ! dfu-util -l 2>/dev/null | grep -qi '0483:df11'; then
          echo "" >&2
          echo "ERROR: Q0 Max not detected in DFU mode (no 0483:DF11 device)." >&2
          echo "       Re-do the steps above; on macOS you may also need to" >&2
          echo "       grant USB access to the terminal in System Settings →" >&2
          echo "       Privacy & Security if it prompts." >&2
          exit 1
        fi

        echo ""
        echo "Flashing $FIRMWARE ..."
        dfu-util -a 0 -d 0483:DF11 -s 0x08000000:leave -D "$FIRMWARE"
        echo ""
        echo "Flash complete. The keyboard rebooted into the new firmware."
        echo "Hold Fn (bottom-left) + tap M1 (top-left) to test the manual"
        echo "layer-cycle keybind."
      '';
    };

in {
  inherit mkFirmware mkFlashScript;
}
