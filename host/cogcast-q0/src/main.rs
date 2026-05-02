#![forbid(unsafe_code)]

mod bridge;
mod config;
mod events;
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
    info!(daemon = %cli.daemon, slots_toml = %cli.slots_toml.display(), "cogcast-q0 starting");

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
        let bridge = bridge::Bridge::new(cli.daemon.clone(), cfg, hid);
        if let Err(e) = bridge.run().await {
            warn!(error = %e, "bridge exited; restarting in {:?}", backoff);
        }
        tokio::time::sleep(backoff).await;
        backoff = (backoff * 2).min(Duration::from_secs(30));
    }
}
