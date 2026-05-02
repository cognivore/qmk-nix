//! hidapi wrapper for the Q0 Max raw HID interface.
//!
//! Packet format mirrors `firmware-stub/qmk_nix_raw_hid.c`:
//!   - 0x10 COGCAST_PAINT       host → kbd, up to 7 (led, r, g, b) tuples per packet
//!   - 0x11 COGCAST_CLEAR_ALL   host → kbd
//!   - 0x20 SLOT_PRESSED        kbd → host, payload: led_idx, edge

use anyhow::{Context, Result, anyhow};
use hidapi::{HidApi, HidDevice};

/// Q0 Max USB ids (Cable mode). Wireless modes don't expose RAW HID.
const VID: u16 = 0x3434;
const PID: u16 = 0x0800;

/// QMK uses raw HID usage page 0xFF60 / usage 0x61 by convention.
const RAW_USAGE_PAGE: u16 = 0xFF60;
const RAW_USAGE: u16 = 0x61;

/// HID report payload size. 32 bytes for QMK raw HID.
pub const REPORT_BYTES: usize = 32;

/// One frame written to the device. The leading 0x00 is the HID report id
/// prefix that hidapi requires on macOS / Linux (hidraw).
const FRAME_BYTES: usize = REPORT_BYTES + 1;

pub struct Hid {
    dev: HidDevice,
}

impl Hid {
    pub fn open() -> Result<Self> {
        let api = HidApi::new().context("hidapi init")?;
        let info = api
            .device_list()
            .find(|d| {
                d.vendor_id() == VID
                    && d.product_id() == PID
                    && d.usage_page() == RAW_USAGE_PAGE
                    && d.usage() == RAW_USAGE
            })
            .ok_or_else(|| {
                anyhow!(
                    "Q0 Max raw-HID interface not found ({:04x}:{:04x} usage_page {:04x}); is the keyboard plugged in via USB cable (not 2.4G/BT)?",
                    VID, PID, RAW_USAGE_PAGE
                )
            })?
            .clone();
        let dev = info.open_device(&api).context("hidapi open_device")?;
        dev.set_blocking_mode(false).context("set_blocking_mode")?;
        Ok(Self { dev })
    }

    /// Send a single 32-byte payload (with the 0x00 report-id prefix).
    pub fn write(&self, payload: &[u8]) -> Result<()> {
        if payload.len() != REPORT_BYTES {
            return Err(anyhow!(
                "raw HID payload must be {REPORT_BYTES} bytes (got {})",
                payload.len()
            ));
        }
        let mut frame = [0u8; FRAME_BYTES];
        frame[1..].copy_from_slice(payload);
        let n = self.dev.write(&frame).context("hid write")?;
        if n != FRAME_BYTES {
            return Err(anyhow!(
                "short hid write: expected {FRAME_BYTES} bytes, wrote {n}"
            ));
        }
        Ok(())
    }

    /// Read a single 32-byte payload from the device. Returns `Ok(None)` on
    /// timeout. macOS / Linux hidraw reads include no leading report-id byte.
    pub fn read_timeout(&self, timeout_ms: i32) -> Result<Option<[u8; REPORT_BYTES]>> {
        let mut buf = [0u8; REPORT_BYTES];
        let n = self.dev.read_timeout(&mut buf, timeout_ms).context("hid read")?;
        if n == 0 {
            return Ok(None);
        }
        Ok(Some(buf))
    }

    /// Convenience: paint up to 7 (led, r, g, b) tuples in one packet.
    pub fn paint(&self, tuples: &[(u8, u8, u8, u8)]) -> Result<()> {
        if tuples.is_empty() {
            return Ok(());
        }
        let n = tuples.len().min(7);
        let mut buf = [0u8; REPORT_BYTES];
        buf[0] = 0x10;
        buf[1] = u8::try_from(n).expect("n ≤ 7");
        for (i, t) in tuples.iter().take(n).enumerate() {
            let off = 2 + i * 4;
            buf[off] = t.0;
            buf[off + 1] = t.1;
            buf[off + 2] = t.2;
            buf[off + 3] = t.3;
        }
        self.write(&buf)
    }

    pub fn clear_all(&self) -> Result<()> {
        let mut buf = [0u8; REPORT_BYTES];
        buf[0] = 0x11;
        self.write(&buf)
    }
}
