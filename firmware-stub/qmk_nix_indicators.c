// RGB matrix indicator: while an app layer is active, dim every LED to black
// and light only the keys that app's LedSet declared, in the colour declared.
// When no app layer is active, return false so the stock animation plays.
//
// `qmk_nix_indicators_per_layer` is generated in keymap.c — entries for layers
// that don't carry indicators are zero-initialised (NULL leds, count 0).

#include "quantum.h"
#include "rgb_matrix.h"
#include "qmk_nix_layers.h"

#ifdef QMK_NIX_COGCAST_ENABLED
#include "qmk_nix_slots.h"
#endif

typedef struct { uint8_t led; uint8_t r; uint8_t g; uint8_t b; } qmk_nix_led_t;
typedef struct { const qmk_nix_led_t *leds; uint8_t count; } qmk_nix_led_set_t;

extern const qmk_nix_led_set_t qmk_nix_indicators_per_layer[QMK_NIX_LAYER_COUNT];

static int8_t highest_active_app_layer(void) {
    for (int8_t i = QMK_NIX_APP_LAST; i >= QMK_NIX_APP_FIRST; i--) {
        if (layer_state & ((layer_state_t)1 << i)) {
            return i;
        }
    }
    return -1;
}

bool rgb_matrix_indicators_user(void) {
    int8_t app = highest_active_app_layer();
    if (app >= 0) {
        rgb_matrix_set_color_all(0, 0, 0);

        const qmk_nix_led_set_t *set = &qmk_nix_indicators_per_layer[app];
        for (uint8_t i = 0; i < set->count; i++) {
            const qmk_nix_led_t *e = &set->leds[i];
            rgb_matrix_set_color(e->led, e->r, e->g, e->b);
        }
        return false;  // allow keychron_common kb-level indicators to overlay
    }

    // No app active. Kill the stock rainbow — the bare numpad surface
    // stays dark unless something has a reason to light it.
    rgb_matrix_set_color_all(0, 0, 0);

#ifdef QMK_NIX_COGCAST_ENABLED
    // Cogcast paints its slot indicators on top of the dark base, so the
    // agentic surface remains visible.
    qmk_nix_slots_apply();
#endif

    return false;
}
