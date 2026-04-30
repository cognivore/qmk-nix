// RAW HID protocol handler.
//
// Packet format (32 bytes, little-endian):
//   [0]    command (0x01 = SET_LAYER_MASK)
//   [1-3]  reserved (must be zero)
//   [4-7]  uint32 overlay layer mask — bits 1..30 may be set
//   [8-31] padding
//
// On SET_LAYER_MASK we perform a single atomic layer_state_set, with bits 0
// (BASE) and 31 (FN) masked out so the host can't disturb them. BASE lives in
// default_layer_state (separate variable, always on); FN is the held-momentary
// function layer.

#include "quantum.h"
#include "raw_hid.h"
#include "qmk_nix_layers.h"

// Keychron-fork signature: a `src` parameter precedes the buffer to identify
// the transport (USB / 2.4G / Bluetooth). We treat all transports the same.
void raw_hid_receive(uint8_t src, uint8_t *data, uint8_t length) {
    (void)src;
    if (length < 8) return;
    if (data[0] != 0x01) return;  // SET_LAYER_MASK is the only command in v1

    layer_state_t mask =
          (layer_state_t)data[4]
        | ((layer_state_t)data[5] << 8)
        | ((layer_state_t)data[6] << 16)
        | ((layer_state_t)data[7] << 24);

    mask &= ~((layer_state_t)1 << LAYER_BASE);
    mask &= ~((layer_state_t)1 << LAYER_FN);

    layer_state_set(mask);
}
