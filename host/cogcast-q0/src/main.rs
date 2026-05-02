#![forbid(unsafe_code)]

mod bridge;
mod config;
mod events;
mod focus;
mod hid;
mod keymap;

use std::path::PathBuf;
use std::time::Duration;

use anyhow::Result;
use clap::Parser;
use tracing::{info, warn};

#[derive(Parser, Debug)]
#[command(
    name = "cogcast-q0",
    about = "RAW HID bridge between cogworkd and a Keychron Q0 Max running cogcast firmware"
)]
struct Cli {
    /// Base URL of the cogworkd daemon.
    #[arg(long, env = "COGWORK_DAEMON", default_value = "http://127.0.0.1:7878")]
    daemon: String,

    /// Path to slots.toml (used to map slot_id ↔ physical key ↔ LED).
    #[arg(long, env = "COGWORK_SLOTS_TOML", default_value = "slots.toml")]
    slots_toml: PathBuf,

    /// Modifier the WM uses for workspace-switch chords. mcmonad's default
    /// is Cmd on macOS; set to `option` if you've remapped modMask.
    /// Accepts: cmd|ctrl|opt|shift.
    #[arg(long, env = "COGCAST_WORKSPACE_MOD", default_value = "cmd")]
    workspace_mod: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("cogcast_q0=info,warn")),
        )
        .init();

    let cli = Cli::parse();
    let workspace_mod = focus::Modifier::parse(&cli.workspace_mod)?;
    info!(
        daemon = %cli.daemon,
        slots_toml = %cli.slots_toml.display(),
        workspace_mod = ?workspace_mod,
        "cogcast-q0 starting"
    );

    // Restart on any failure (HID disconnect, daemon down, …) with a
    // generous backoff. Same shape as the SSE reconnect.
    let mut backoff = Duration::from_millis(500);
    loop {
        let cfg = config::SlotsConfig::load(&cli.slots_toml)?;
        info!(n_slots = cfg.slots.len(), "loaded slots.toml");
        let hid = match hid::Hid::open() {
            Ok(h) => h,
            Err(e) => {
                warn!(error = %e, "hid open failed; retry in {:?}", backoff);
                tokio::time::sleep(backoff).await;
                backoff = (backoff * 2).min(Duration::from_secs(30));
                continue;
            }
        };
        let bridge = bridge::Bridge::new(cli.daemon.clone(), cfg, hid, workspace_mod);
        if let Err(e) = bridge.run().await {
            warn!(error = %e, "bridge exited; restarting in {:?}", backoff);
        }
        tokio::time::sleep(backoff).await;
        backoff = (backoff * 2).min(Duration::from_secs(30));
    }
}
