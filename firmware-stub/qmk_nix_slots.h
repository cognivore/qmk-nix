// Cogcast slot indicators + key dispatch.
//
// Compiled in only when the Haskell codegen sets QMK_NIX_COGCAST_ENABLED in
// qmk_nix_layers.h. Other firmware files include this header inside
// `#ifdef QMK_NIX_COGCAST_ENABLED` so the build is bit-identical when
// Cogcast is disabled.

#pragma once

#include "quantum.h"

// Number of LEDs on the Q0 Max with controllable colors. Indices 0..25.
#define QMK_NIX_LED_COUNT 26

// Set the per-LED indicator color. Painted on every matrix scan via
// `qmk_nix_slots_apply` until cleared. r/g/b are direct PWM values.
void qmk_nix_slots_set_color(uint8_t led, uint8_t r, uint8_t g, uint8_t b);

// Clear the indicator for one LED — that LED returns to stock animation.
void qmk_nix_slots_clear(uint8_t led);

// Clear every indicator slot — every LED returns to stock animation.
void qmk_nix_slots_clear_all(void);

// Paint all currently-set indicators onto the rgb_matrix. Returns true if at
// least one LED was painted (so the caller knows whether to suppress stock
// animation overlays).
bool qmk_nix_slots_apply(void);

// Intercept slot keycodes (QMK_NIX_SLOT_KEY_<n>): on press, send a 0x20
// raw-HID report to the host with the LED index. Returns false to consume
// the keypress; returns true if `keycode` is not a slot key.
bool qmk_nix_slots_process(uint16_t keycode, keyrecord_t *record);

// Apply a paint command from a 32-byte raw-HID packet whose first byte is
// 0x10. Format:
//   data[0]   = 0x10
//   data[1]   = N — number of (led, r, g, b) tuples that follow (0..7)
//   data[2..] = N * 4 bytes
void qmk_nix_slots_handle_paint(const uint8_t *data, uint8_t length);
