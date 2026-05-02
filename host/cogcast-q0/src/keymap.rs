//! Static map: Q0 Max position name (`"P0"`, `"Esc"`, …) ↔ LED index.
//!
//! Mirrors `src/QmkNix/Positions/Q0MaxEncoder.hs`. Excludes the encoder
//! (no LED) and the user-reserved positions (M1..M5, PMns, PPls, PEnt).

use std::collections::HashMap;

/// `(position name, led index)` for every position on the Q0 Max that has
/// a controllable LED. Includes the reserved ones — the bridge filters by
/// what `slots.toml` references.
pub const POSITIONS: &[(&str, u8)] = &[
    ("Esc", 0), ("Del", 1), ("Tab", 2), ("Bspc", 3),
    ("M1", 4), ("NumLk", 5), ("PSls", 6), ("PAst", 7), ("PMns", 8),
    ("M2", 9), ("P7", 10), ("P8", 11), ("P9", 12), ("PPls", 13),
    ("M3", 14), ("P4", 15), ("P5", 16), ("P6", 17),
    ("M4", 18), ("P1", 19), ("P2", 20), ("P3", 21), ("PEnt", 22),
    ("M5", 23), ("P0", 24), ("PDot", 25),
];

#[must_use]
pub fn name_to_led() -> HashMap<&'static str, u8> {
    POSITIONS.iter().copied().collect()
}

#[must_use]
pub fn led_to_name() -> HashMap<u8, &'static str> {
    POSITIONS.iter().map(|(n, l)| (*l, *n)).collect()
}
