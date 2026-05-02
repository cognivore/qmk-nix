//! Subscriber for cogworkd's `/slots/events` SSE stream + companion REST.
//!
//! We model only what the bridge needs: state → color and slot id. Wire
//! shapes mirror `cogwork_core::slots`; we deserialize via serde and let
//! anything we don't recognise pass through (`#[serde(other)]` on enums is
//! deliberately not used so a daemon-side schema bump is a hard error here).

use serde::Deserialize;

#[derive(Clone, Copy, Debug, Default)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Color {
    pub const OFF: Self = Self { r: 0, g: 0, b: 0 };
    pub const RED: Self = Self { r: 255, g: 0, b: 0 };
    pub const GREEN: Self = Self { r: 0, g: 255, b: 0 };
    pub const YELLOW: Self = Self { r: 255, g: 200, b: 0 };
    pub const CYAN: Self = Self { r: 0, g: 200, b: 255 };
    pub const MAGENTA: Self = Self { r: 255, g: 0, b: 255 };
}

#[derive(Clone, Debug, Deserialize)]
#[serde(tag = "tag", rename_all = "snake_case")]
pub enum SlotState {
    Unbound,
    Idle,
    Queued { run: String },
    Running { run: String },
    Succeeded { run: String, at: String },
    Failed {
        run: String,
        at: String,
        kind: serde_json::Value,
    },
    Orphaned { run: String },
}

#[derive(Clone, Debug, Deserialize)]
pub struct SlotRow {
    pub slot: u8,
    pub pipeline: Option<String>,
    pub state: SlotState,
    pub updated_at: String,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum SlotEvent {
    Bound {
        slot: u8,
        pipeline: String,
        at: String,
    },
    Unbound {
        slot: u8,
        at: String,
    },
    Enqueued {
        slot: u8,
        run: String,
        at: String,
    },
    Started {
        slot: u8,
        run: String,
        at: String,
    },
    Finished {
        slot: u8,
        run: String,
        outcome: serde_json::Value,
        at: String,
    },
    Orphaned {
        slot: u8,
        run: String,
        at: String,
    },
}

impl SlotEvent {
    pub fn slot(&self) -> u8 {
        match self {
            Self::Bound { slot, .. }
            | Self::Unbound { slot, .. }
            | Self::Enqueued { slot, .. }
            | Self::Started { slot, .. }
            | Self::Finished { slot, .. }
            | Self::Orphaned { slot, .. } => *slot,
        }
    }
}

/// Pure: state → indicator color. Mirror of `cogwork_core::slots::state_color`.
/// Unbound and Failed share RED on purpose (both mean "needs your attention").
#[must_use]
pub fn state_color(state: &SlotState) -> Color {
    match state {
        SlotState::Idle => Color::OFF,
        SlotState::Queued { .. } => Color::CYAN,
        SlotState::Running { .. } => Color::GREEN,
        SlotState::Succeeded { .. } => Color::YELLOW,
        SlotState::Orphaned { .. } => Color::MAGENTA,
        SlotState::Unbound | SlotState::Failed { .. } => Color::RED,
    }
}
