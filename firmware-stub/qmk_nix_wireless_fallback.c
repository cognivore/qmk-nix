// Manual layer-cycle keybind for use without the host daemon (or in wireless
// mode, where RAW HID is unreachable on the Q0 Max).
//
// Pressing QMK_NIX_CYCLE_APP advances through the registered app slots:
//   no-app → app[0] → app[1] → ... → app[N-1] → no-app → ...
//
// Each app's mask (layer + its categories) is precomputed by qmk-nix-codegen
// and emitted as `qmk_nix_app_masks[]` in the generated keymap.c.

#include "quantum.h"
#include "qmk_nix_layers.h"

extern const layer_state_t qmk_nix_app_masks[];

// Bits CAT_FIRST..APP_LAST (1..30): everything except BASE (0) and FN (31).
#define QMK_NIX_DAEMON_BITS ((layer_state_t)0x7FFFFFFEU)

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    if (keycode != QMK_NIX_CYCLE_APP) return true;
    if (!record->event.pressed) return false;

#if QMK_NIX_APP_COUNT > 0
    int8_t cur = -1;
    for (uint8_t i = 0; i < QMK_NIX_APP_COUNT; i++) {
        if ((layer_state & qmk_nix_app_masks[i]) == qmk_nix_app_masks[i]) {
            cur = (int8_t)i;
            break;
        }
    }

    layer_state_t cleared = layer_state & ~QMK_NIX_DAEMON_BITS;
    int8_t next = cur + 1;

    if (next >= (int8_t)QMK_NIX_APP_COUNT) {
        layer_state_set(cleared);
    } else {
        layer_state_set(cleared | qmk_nix_app_masks[next]);
    }
#endif

    return false;
}
