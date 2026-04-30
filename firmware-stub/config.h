#pragma once

// LAYER_FN lives at index 31 (above all app slots), so the keymap layer count
// reaches 32. The default 16-bit layer_state_t can't represent that — bump to
// 32-bit (sets MAX_LAYER = 32).
#define LAYER_STATE_32BIT
