//! Bridge orchestration.
//!
//! Two concurrent loops:
//!
//! 1. **Subscribe loop**: GET `<daemon>/slots/events` (SSE), maintain a
//!    `slot_id → SlotState` snapshot, and on every change push a paint
//!    packet for that slot's LED.
//!
//! 2. **HID listen loop**: read 32-byte raw-HID reports from the keyboard;
//!    on `[0x20, led_idx, edge=1, ...]`, look up `led_idx → slot_id` from
//!    `slots.toml` and POST `<daemon>/slots/<slot_id>/trigger`.
//!
//! Both loops share the same `Hid` handle and `Reqwest` client. Reconnect
//! is exponential-backoff capped at 30s; the firmware buffer is correct
//! across drops because the daemon resends a full snapshot on subscribe.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, Result};
use eventsource_stream::Eventsource;
use futures::StreamExt;
use tokio::sync::Mutex;
use tracing::{debug, error, info, warn};

use crate::config::SlotsConfig;
use crate::events::{SlotEvent, SlotRow, SlotState, state_color};
use crate::focus::{self, Modifier};
use crate::hid::Hid;

#[derive(Clone)]
pub struct Bridge {
    pub daemon: String,
    pub config: Arc<SlotsConfig>,
    pub hid: Arc<Mutex<Hid>>,
    pub http: reqwest::Client,
    pub state: Arc<Mutex<HashMap<u8, SlotState>>>,
    pub workspace_mod: Modifier,
}

impl Bridge {
    pub fn new(
        daemon: String,
        config: SlotsConfig,
        hid: Hid,
        workspace_mod: Modifier,
    ) -> Self {
        Self {
            daemon: daemon.trim_end_matches('/').to_string(),
            config: Arc::new(config),
            hid: Arc::new(Mutex::new(hid)),
            http: reqwest::Client::builder()
                .build()
                .expect("reqwest client"),
            state: Arc::new(Mutex::new(HashMap::new())),
            workspace_mod,
        }
    }

    /// Run forever: spawn both loops, never return until cancelled.
    pub async fn run(self) -> Result<()> {
        // Initial snapshot: GET /slots, paint everything once.
        if let Err(e) = self.initial_paint().await {
            warn!(error = %e, "initial paint failed; SSE loop will recover");
        }

        let sub = tokio::spawn(self.clone().subscribe_loop());
        let lis = tokio::spawn(self.clone().hid_listen_loop());

        // First task to exit kills the other and we restart from main.
        tokio::select! {
            r = sub => r??,
            r = lis => r??,
        }
        Ok(())
    }

    async fn initial_paint(&self) -> Result<()> {
        let url = format!("{}/slots", self.daemon);
        let rows: Vec<SlotRow> = self.http.get(&url).send().await?.json().await?;
        let mut snap = self.state.lock().await;
        snap.clear();
        for r in &rows {
            snap.insert(r.slot, r.state.clone());
        }
        drop(snap);
        let tuples = self.full_paint(&rows);
        self.send_paint(&tuples).await?;
        info!(n_rows = rows.len(), n_painted = tuples.len(), "initial paint applied");
        Ok(())
    }

    /// Paint every slot in slots.toml. Slots without a ledger row are
    /// treated as Unbound (RED). This keeps the keyboard surface fully
    /// determined even before any binding event has fired.
    fn full_paint(&self, rows: &[SlotRow]) -> Vec<(u8, u8, u8, u8)> {
        let mut out = Vec::with_capacity(self.config.slots.len());
        for entry in &self.config.slots {
            let row = rows.iter().find(|r| r.slot == entry.id);
            let c = match row {
                Some(r) => state_color(&r.state),
                None => state_color(&SlotState::Unbound),
            };
            out.push((entry.led, c.r, c.g, c.b));
        }
        out
    }

    async fn subscribe_loop(self) -> Result<()> {
        let url = format!("{}/slots/events", self.daemon);
        let mut backoff = Duration::from_millis(500);
        loop {
            match self.subscribe_once(&url).await {
                Ok(()) => {
                    warn!("SSE stream ended; reconnecting");
                    backoff = Duration::from_millis(500);
                }
                Err(e) => {
                    warn!(error = %e, "SSE error; backing off {:?}", backoff);
                    tokio::time::sleep(backoff).await;
                    backoff = (backoff * 2).min(Duration::from_secs(30));
                }
            }
            // On reconnect, refresh the full snapshot so we can't drift.
            if let Err(e) = self.initial_paint().await {
                warn!(error = %e, "snapshot refresh after reconnect failed");
            }
        }
    }

    async fn subscribe_once(&self, url: &str) -> Result<()> {
        let resp = self
            .http
            .get(url)
            .header("accept", "text/event-stream")
            .send()
            .await?;
        if !resp.status().is_success() {
            anyhow::bail!("subscribe got HTTP {}", resp.status());
        }
        info!(url, "subscribed to lifecycle events");
        let mut stream = resp.bytes_stream().eventsource();
        while let Some(item) = stream.next().await {
            let ev = item.context("SSE chunk")?;
            let parsed: SlotEvent = match serde_json::from_str(&ev.data) {
                Ok(v) => v,
                Err(e) => {
                    warn!(error = %e, data = %ev.data, "skipping malformed event");
                    continue;
                }
            };
            self.apply_event(parsed).await?;
        }
        Ok(())
    }

    async fn apply_event(&self, ev: SlotEvent) -> Result<()> {
        let slot = ev.slot();
        let new_state = match &ev {
            SlotEvent::Bound { .. } => Some(SlotState::Idle),
            SlotEvent::Unbound { .. } => Some(SlotState::Unbound),
            SlotEvent::Enqueued { run, .. } => Some(SlotState::Queued { run: run.clone() }),
            SlotEvent::Started { run, .. } => Some(SlotState::Running { run: run.clone() }),
            SlotEvent::Finished {
                run,
                outcome,
                at,
                ..
            } => {
                if outcome.get("result").and_then(|v| v.as_str()) == Some("ok") {
                    Some(SlotState::Succeeded {
                        run: run.clone(),
                        at: at.clone(),
                    })
                } else {
                    Some(SlotState::Failed {
                        run: run.clone(),
                        at: at.clone(),
                        kind: outcome
                            .get("kind")
                            .cloned()
                            .unwrap_or(serde_json::Value::Null),
                    })
                }
            }
            SlotEvent::Orphaned { run, .. } => Some(SlotState::Orphaned { run: run.clone() }),
        };

        if let Some(s) = new_state {
            let mut snap = self.state.lock().await;
            snap.insert(slot, s.clone());
            drop(snap);
            // Repaint just this slot.
            if let Some(entry) = self.config.by_id.get(&slot) {
                let c = state_color(&s);
                self.send_paint(&[(entry.led, c.r, c.g, c.b)]).await?;
                debug!(slot, led = entry.led, color = ?c, "painted");
            } else {
                debug!(slot, "event for slot not in slots.toml; ignoring");
            }
        }
        Ok(())
    }

    async fn send_paint(&self, tuples: &[(u8, u8, u8, u8)]) -> Result<()> {
        // Up to 7 tuples per HID packet.
        for chunk in tuples.chunks(7) {
            let hid = self.hid.lock().await;
            hid.paint(chunk)?;
        }
        Ok(())
    }

    async fn hid_listen_loop(self) -> Result<()> {
        loop {
            let frame = {
                let hid = self.hid.lock().await;
                hid.read_timeout(50)?
            };
            let Some(buf) = frame else {
                tokio::task::yield_now().await;
                continue;
            };
            if buf[0] != 0x20 || buf[2] != 0x01 {
                continue;
            }
            let led_idx = buf[1];
            let Some(entry) = self.config.by_led.get(&led_idx) else {
                debug!(led_idx, "key press for unconfigured led");
                continue;
            };

            // Workspace switch first, so the user is already looking at the
            // right workspace when the run kicks off. Failures here are
            // surfaced but never block the trigger.
            if let Some(ws) = entry.workspace.as_deref() {
                if let Err(e) = focus::focus_workspace(self.workspace_mod, ws).await {
                    warn!(slot = entry.id, workspace = %ws, error = %e, "workspace focus failed");
                } else {
                    debug!(slot = entry.id, workspace = %ws, "focused workspace");
                }
            }

            let url = format!("{}/slots/{}/trigger", self.daemon, entry.id);
            match self.http.post(&url).send().await {
                Ok(r) if r.status() == reqwest::StatusCode::ACCEPTED => {
                    info!(slot = entry.id, key = %entry.key, "triggered");
                }
                Ok(r) => {
                    warn!(slot = entry.id, status = %r.status(), "trigger rejected");
                }
                Err(e) => {
                    error!(slot = entry.id, error = %e, "trigger POST failed");
                }
            }
        }
    }
}
