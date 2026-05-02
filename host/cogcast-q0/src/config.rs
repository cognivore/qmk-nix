//! Read `slots.toml` and resolve slot_id ↔ led_index.

use std::collections::HashMap;
use std::path::Path;

use anyhow::{Context, Result, anyhow};
use serde::Deserialize;

use crate::keymap::name_to_led;

#[derive(Clone, Debug, Deserialize)]
struct RawSlot {
    id: u8,
    key: String,
    #[serde(default)]
    pipeline: Option<String>,
    #[serde(default)]
    workspace: Option<String>,
}

#[derive(Clone, Debug, Deserialize)]
struct RawConfig {
    #[serde(default, rename = "slot")]
    slots: Vec<RawSlot>,
}

#[derive(Clone, Debug)]
pub struct SlotEntry {
    pub id: u8,
    pub key: String,
    pub led: u8,
    /// Optional mcmonad/xmonad workspace name to focus on press, before
    /// the trigger fires. The bridge sends this as a synthetic
    /// `<modifier>+<single letter>` chord via osascript on macOS.
    pub workspace: Option<String>,
}

#[derive(Clone, Debug)]
pub struct SlotsConfig {
    pub slots: Vec<SlotEntry>,
    pub by_id: HashMap<u8, SlotEntry>,
    pub by_led: HashMap<u8, SlotEntry>,
}

impl SlotsConfig {
    pub fn load(path: &Path) -> Result<Self> {
        let bytes = std::fs::read(path).with_context(|| format!("reading {}", path.display()))?;
        let text = std::str::from_utf8(&bytes)
            .with_context(|| format!("{} is not utf-8", path.display()))?;
        Self::parse(text)
    }

    pub fn parse(text: &str) -> Result<Self> {
        let raw: RawConfig = toml::from_str(text).context("parsing slots.toml")?;
        let leds = name_to_led();
        let mut entries = Vec::with_capacity(raw.slots.len());
        for r in &raw.slots {
            let led = *leds
                .get(r.key.as_str())
                .ok_or_else(|| anyhow!("unknown key `{}` in slots.toml", r.key))?;
            entries.push(SlotEntry {
                id: r.id,
                key: r.key.clone(),
                led,
                workspace: r.workspace.clone(),
            });
        }
        let by_id = entries.iter().cloned().map(|e| (e.id, e)).collect();
        let by_led = entries.iter().cloned().map(|e| (e.led, e)).collect();
        Ok(Self {
            slots: entries,
            by_id,
            by_led,
        })
    }
}
