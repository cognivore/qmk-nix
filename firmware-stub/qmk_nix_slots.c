// Cogcast slot subsystem: per-LED indicator buffer + slot keypress dispatch
// + raw-HID paint command handler.
//
// Compiled in only when QMK_NIX_COGCAST_ENABLED is set (rules.mk gates this
// file in/out via the codegen).

#include "quantum.h"
#include "raw_hid.h"
#include "rgb_matrix.h"

#include "qmk_nix_layers.h"
#include "qmk_nix_slots.h"

typedef struct {
    bool    active;
    uint8_t r;
    uint8_t g;
    uint8_t b;
} slot_indicator_t;

static slot_indicator_t g_slots[QMK_NIX_LED_COUNT];

void qmk_nix_slots_set_color(uint8_t led, uint8_t r, uint8_t g, uint8_t b) {
    if (led >= QMK_NIX_LED_COUNT) return;
    g_slots[led].active = true;
    g_slots[led].r      = r;
    g_slots[led].g      = g;
    g_slots[led].b      = b;
}

void qmk_nix_slots_clear(uint8_t led) {
    if (led >= QMK_NIX_LED_COUNT) return;
    g_slots[led].active = false;
}

void qmk_nix_slots_clear_all(void) {
    for (uint8_t i = 0; i < QMK_NIX_LED_COUNT; i++) {
        g_slots[i].active = false;
    }
}

bool qmk_nix_slots_apply(void) {
    bool any = false;
    for (uint8_t i = 0; i < QMK_NIX_LED_COUNT; i++) {
        if (g_slots[i].active) {
            rgb_matrix_set_color(i, g_slots[i].r, g_slots[i].g, g_slots[i].b);
            any = true;
        }
    }
    return any;
}

bool qmk_nix_slots_process(uint16_t keycode, keyrecord_t *record) {
    if (keycode < QMK_NIX_SLOT_KEY_FIRST || keycode > QMK_NIX_SLOT_KEY_LAST) {
        return true;  // not a slot key — propagate normally
    }
    if (!record->event.pressed) {
        return false;  // suppress release
    }

    uint8_t led_idx = (uint8_t)(keycode - QMK_NIX_SLOT_KEY_FIRST);

    // Report format (32 bytes):
    //   [0] = 0x20   (slot-pressed report)
    //   [1] = led_idx
    //   [2] = 0x01   (edge: 1 = pressed)
    //   [3..31] padding
    uint8_t buf[32] = {0};
    buf[0] = 0x20;
    buf[1] = led_idx;
    buf[2] = 0x01;
    raw_hid_send(buf, sizeof(buf));
    return false;
}

void qmk_nix_slots_handle_paint(const uint8_t *data, uint8_t length) {
    if (length < 2) return;
    uint8_t n = data[1];
    if (n > 7) n = 7;                   // tuples don't fit beyond byte 30
    if ((size_t)2 + (size_t)n * 4 > length) return;
    for (uint8_t i = 0; i < n; i++) {
        const uint8_t *t = &data[2 + (size_t)i * 4];
        qmk_nix_slots_set_color(t[0], t[1], t[2], t[3]);
    }
}
