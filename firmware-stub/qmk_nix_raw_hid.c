// RAW HID protocol handler.
//
// Packet format (32 bytes, little-endian):
//   [0]   command:
//           0x01 = SET_LAYER_MASK
//           0x10 = COGCAST_PAINT       (cogcast)
//           0x11 = COGCAST_CLEAR_ALL   (cogcast)
//   tail  command-specific
//
// 0x01 SET_LAYER_MASK
//   [1-3]  reserved
//   [4-7]  uint32 overlay layer mask — bits 1..30 may be set
//   [8-31] padding
//   Performs a single atomic `layer_state_set`, with bits 0 (BASE) and 31
//   (FN) masked out so the host can't disturb them.
//
// 0x10 COGCAST_PAINT
//   [1]    N — number of (led, r, g, b) tuples that follow (0..7)
//   [2..]  N * 4 bytes
//   Updates the slot indicator buffer; rendered every matrix scan.
//
// 0x11 COGCAST_CLEAR_ALL
//   No payload. Clears every slot indicator (LEDs return to stock anim).

#include "quantum.h"
#include "raw_hid.h"
#include "qmk_nix_layers.h"

#ifdef QMK_NIX_COGCAST_ENABLED
#include "qmk_nix_slots.h"
#endif

// Keychron-fork signature: a `src` parameter precedes the buffer to identify
// the transport (USB / 2.4G / Bluetooth). We treat all transports the same.
void raw_hid_receive(uint8_t src, uint8_t *data, uint8_t length) {
    (void)src;
    if (length < 1) return;

    switch (data[0]) {
        case 0x01: {
            if (length < 8) return;
            layer_state_t mask =
                  (layer_state_t)data[4]
                | ((layer_state_t)data[5] << 8)
                | ((layer_state_t)data[6] << 16)
                | ((layer_state_t)data[7] << 24);
            mask &= ~((layer_state_t)1 << LAYER_BASE);
            mask &= ~((layer_state_t)1 << LAYER_FN);
            layer_state_set(mask);
            return;
        }
#ifdef QMK_NIX_COGCAST_ENABLED
        case 0x10:
            qmk_nix_slots_handle_paint(data, length);
            return;
        case 0x11:
            qmk_nix_slots_clear_all();
            return;
#endif
        default:
            return;
    }
}
