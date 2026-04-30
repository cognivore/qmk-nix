# qmk-nix

Declarative custom QMK firmware for the **Keychron Q0 Max** (encoder variant), built hermetically from a Haskell DSL via Nix, with a macOS frontmost-app layer-switching daemon (Hammerspoon + RAW HID) coming next.

This README walks you through **building and flashing** the included Adobe Illustrator plugin onto a connected Q0 Max, and **how to toggle the layer manually** (the host daemon is the next phase; this firmware works standalone via a keyboard combo).

---

## Requirements

- macOS (Apple Silicon, aarch64-darwin) — Linux works too if you build there.
- [Nix](https://nixos.org/download.html) with flakes enabled.
- A **Keychron Q0 Max with rotary encoder**, mode switch set to **Cable**, USB cable connected directly to the host.

That's it. No system QMK, no system Rust, no Homebrew. Everything is fetched and built by Nix.

---

## What this firmware does

The default keymap is the **stock Keychron Q0 Max keymap** (BASE + FN), lifted verbatim from `Keychron/qmk_firmware @ 2025q3`. The Illustrator plugin layers an overlay on top:

- **Numpad 8 / 2** → Page Up / Page Down (vertical viewport scroll)
- **Numpad 4 / 6** → ⌘+Page Up / ⌘+Page Down (horizontal viewport scroll)
- **Encoder rotation** → ⌘+= / ⌘+− (zoom in / out, inherited from `designTools` category)

**Tip**: enable Illustrator → Preferences → Performance → **Animated Zoom** (requires GPU Performance) so the encoder zooms toward the cursor, not the canvas centre.

When the Illustrator layer is active, the **four cardinal numpad keys (P2, P4, P6, P8) glow brown**; every other LED is dark. Switching the layer off restores the stock RGB animation.

---

## Build

```bash
cd ~/Github/qmk-nix
nix build .#firmware-illustrator --print-build-logs
ls -lh result/
# → result/q0-max.bin
```

First build downloads GHC, Haskell deps, the Keychron QMK fork, gcc-arm-embedded, and dfu-util. Allow ~15 minutes and a few GB of disk. Subsequent builds are cached.

If you only want to inspect the generated C output without compiling firmware:

```bash
nix develop -c cabal run qmk-nix-codegen -- gen --plugin illustrator -o /tmp/qmk-nix-out
ls /tmp/qmk-nix-out
# → keymap.c  qmk_nix_layers.h  rules.mk  init.lua
```

---

## Flash

Make sure the keyboard's mode switch (back of the keyboard) is set to **Cable** and the USB cable is plugged in directly to your Mac.

Run:

```bash
nix run .#flash-illustrator
```

The script will prompt you to put the keyboard into DFU mode:

1. Set the mode switch to **Cable**.
2. **Unplug** the USB cable.
3. **Hold the `Esc` key** (top row, second key from the left — immediately right of the rotary encoder).
4. **While still holding `Esc`**, plug the USB cable back in.
5. Release `Esc` after ~2 seconds.

In DFU mode the keyboard's RGB will be off (no LED activity at all). Press **Enter** in your terminal to flash. `dfu-util` will write the binary and the keyboard will reboot automatically.

If the script reports `Q0 Max not detected in DFU mode`, redo the steps above and re-run.

---

## Activating the Illustrator layer

There are two ways. Right now only the manual one works (the daemon is the next phase).

### Manual — works today, no daemon required

Hold **Fn** (the bottom-left key on the numpad — the leftmost key in the bottom row) and **tap the top-left macro key** (the leftmost key in the top-left column, position M1 in the qmk-nix DSL).

- 1st press → Illustrator layer **ON**: numpad 8 / 4 / 6 / 2 glow brown, all other LEDs dark, the four navigation bindings + zoom encoder become active.
- 2nd press → Illustrator layer **OFF**: stock RGB animation resumes, BASE keymap behaviour returns.

(With multiple plugins, the same combo cycles through them and back to "no app".)

This is wired into the FN layer so the cycle key only fires when Fn is held; without Fn, the M1 key still produces the stock `MC_1` Keychron macro.

### Automatic — daemon, coming next

The home-manager module that watches `NSWorkspace.didActivateApplicationNotification` via Hammerspoon and sends RAW HID `SET_LAYER_MASK` packets is the next deliverable. Once it lands, opening Adobe Illustrator (`com.adobe.illustrator`) will activate the layer automatically; switching to any other app will deactivate it. The firmware side is fully RAW-HID-ready — no firmware changes needed when the daemon arrives.

---

## What's actually flashed

The build pipeline:

1. **`qmk-nix-codegen` (Haskell binary)** reads the static `defaultLayer` definition + the selected plugin (`illustrator`) and generates four files in `$KEYMAP_DIR`:
   - `keymap.c` — `keymaps[][][]`, `encoder_map[][][]`, LED indicator data tables, app-mask array.
   - `qmk_nix_layers.h` — layer-index `#define`s + custom keycode enum (`QMK_NIX_CYCLE_APP`).
   - `rules.mk` — `SRC += qmk_nix_*.c` so the static support files compile in.
   - `init.lua` — Hammerspoon config (used by the daemon module, not the firmware itself).
2. **Static C** copied alongside (in `firmware-stub/`):
   - `qmk_nix_raw_hid.c` — `raw_hid_receive` handler for SET_LAYER_MASK packets.
   - `qmk_nix_indicators.c` — `rgb_matrix_indicators_user` that lights the active app layer's LEDs.
   - `qmk_nix_wireless_fallback.c` — `process_record_user` handling QMK_NIX_CYCLE_APP.
3. **`qmk compile`** (via nixpkgs `pkgs.qmk`) builds against the Keychron QMK fork pinned in `flake.nix`, with `SKIP_VERSION=yes SKIP_GIT=yes` for reproducibility.
4. **`dfu-util`** flashes the resulting `.bin` over USB.

---

## Adding a new app plugin

Plugins live in `src/QmkNix/Plugins/Apps/`. To add Figma:

1. Create `src/QmkNix/Plugins/Apps/Figma.hs`:

   ```haskell
   module QmkNix.Plugins.Apps.Figma (figma) where

   import Data.Map.Strict qualified as M
   import QmkNix.Keycodes
   import QmkNix.Plugins.Categories.DesignTools (designTools)
   import QmkNix.Positions.Q0MaxEncoder
   import QmkNix.Types

   figma :: AppLayer
   figma = AppLayer
     { appName       = "figma"
     , appBundleId   = ExactBundle "com.figma.Desktop"
     , appCategories = [designTools]
     , appLeds       = LedSet [P2, P4, P6, P8] cyan
     , appKeymap     = M.fromList
         [ (P8, kc "PGUP"), (P2, kc "PGDN")
         -- ... whatever bindings make sense for Figma
         ]
     , appEncoder    = EncoderInherit
     }
   ```

2. Register it in `src/QmkNix/Plugins/Registry.hs`:

   ```haskell
   import QmkNix.Plugins.Apps.Figma qualified as Figma

   availableApps :: [Text]
   availableApps = ["figma", "illustrator"]

   lookupApp :: Text -> Maybe AppLayer
   lookupApp = \case
     "figma"       -> Just Figma.figma
     "illustrator" -> Just Illustrator.illustrator
     _             -> Nothing
   ```

3. Add it as a module in `qmk-nix.cabal` under `library.exposed-modules`.
4. Build a firmware including it: in `flake.nix`, add or modify a `mkFirmware { plugins = [ "illustrator" "figma" ]; }` entry, and a matching `mkFlashScript`.

Keep contributions in this repo — there's no consumer-side plugin extension by design (the type system catches typos and invalid keycodes at GHC compile time, not at firmware flash time).

---

## Tests

```bash
nix develop -c cabal test --test-options='--accept'   # bootstrap golden snapshots once
git add tests/golden && git commit -m "snapshot goldens"
nix develop -c cabal test                             # subsequent regression runs
```

Goldens cover `keymap.c`, `qmk_nix_layers.h`, `rules.mk`, and `init.lua` for the `illustrator-only` configuration. Any unintended change in generated output will fail CI.

---

## Layer-index convention

| Index | Range | Use |
|-------|-------|-----|
| 0     | exactly | `LAYER_BASE` — stock numpad keymap, lives in `default_layer_state`, always on |
| 1–7   | inclusive | category layers (e.g. `designTools`), auto-assigned alphabetically |
| 8–30  | inclusive | app-specific layers (e.g. `illustrator`), auto-assigned alphabetically |
| 31    | exactly | `LAYER_FN` — RGB / media / Bluetooth-pair controls; held priority above apps so Fn always wins |

The host's `SET_LAYER_MASK` packet sets bits in `layer_state` (the overlay mask). BASE and FN are masked out by the firmware so only categories + apps are host-controllable.

---

## Caveats

- **Wireless mode disables RAW HID** — the Q0 Max's BT/2.4G transports don't expose a RAW HID interface. Use Cable mode for daemon-driven switching, or the manual Fn+M1 keybind in wireless.
- **`pkgs.qmk` on aarch64-darwin** — has historically needed `NIX_CFLAGS_COMPILE` scrubbed before invoking `arm-none-eabi-gcc`. The `mkFirmware` derivation handles this automatically.
- **TCC permissions** (relevant once the daemon lands) — Hammerspoon needs Accessibility granted manually on first launch; that grant is path-specific and Nix store paths change on every rebuild, so the home-manager module will install via a stable symlink + ad-hoc codesign.
- **No Windows support** — bundle-ID matching, encoder Cmd bindings, and the daemon are macOS-only by design.

---

## Repository layout

```
qmk-nix/
├── flake.nix                              # inputs (Keychron QMK pinned), outputs (codegen, firmware, flash)
├── qmk-nix.cabal
├── cabal.project
├── src/QmkNix/                            # the Haskell DSL + codegen
│   ├── LayerLayout.hs                     # 0 / 1–7 / 8–30 / 31
│   ├── Keycodes.hs                        # Keycode ADT
│   ├── Positions/Q0MaxEncoder.hs          # symbolic positions + matrix/LED tables
│   ├── Types.hs
│   ├── Resolve.hs                         # auto-assign indices, mask computation, validation
│   ├── Render/                            # pretty-printers (pure Haskell, no templating libs)
│   │   ├── KeymapC.hs
│   │   ├── LayersH.hs
│   │   ├── RulesMk.hs
│   │   ├── InitLua.hs
│   │   └── Common.hs
│   └── Plugins/
│       ├── Default.hs                     # stock BASE + FN, lifted from upstream
│       ├── Categories/DesignTools.hs
│       ├── Apps/Illustrator.hs
│       └── Registry.hs                    # name → AppLayer dispatch
├── app/Codegen.hs                         # CLI: list-plugins, gen --plugin NAME --out DIR
├── firmware-stub/                         # static C (raw_hid, indicators, manual cycle)
│   ├── qmk_nix_raw_hid.c
│   ├── qmk_nix_indicators.c
│   └── qmk_nix_wireless_fallback.c
├── nix/
│   └── lib.nix                            # mkFirmware, mkFlashScript
├── tests/
│   ├── Spec.hs                            # tasty-golden
│   └── golden/illustrator/
└── examples/                              # (next: standalone consumer flake)
```

---

## License

TBD by upstream user. The lifted upstream Keychron BASE/FN keymap retains its original GPL-2.0+ via the firmware-stub C copies; the Haskell DSL/codegen is the user's to license as they wish.
