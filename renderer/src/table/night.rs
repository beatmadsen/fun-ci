//! The table's colours, taken from the header's night scenes (design.md, The
//! console): moonlit teal for passed, nebula violet-greys for names and
//! labels, a dusty coral for failed, amber for timed out, blue for running
//! and lilac for a conflict; each a hue of its own, so no two states can be
//! mistaken for each other. Each is red, green and blue, which ratatui takes
//! as a colour, so the table can pale and mix them.

use ratatui::style::Style;

use crate::maths::byte;

pub const BRANCH: [u8; 3] = [0xD8, 0xD4, 0xE8];
/// The name of the row the cursor is on.
pub const CURSOR: [u8; 3] = [0xF2, 0xEF, 0xFA];
pub const LABEL: [u8; 3] = [0x7F, 0x7A, 0x96];
/// A note in italics: a stale trunk, what a short screen left out.
pub const NOTE: [u8; 3] = [0x92, 0x8C, 0xAA];
pub const PASSED: [u8; 3] = [0x6F, 0xB8, 0xAA];
pub const FAILED: [u8; 3] = [0xDC, 0x84, 0x76];
pub const TIMED_OUT: [u8; 3] = [0xE0, 0xAE, 0x70];
pub const RUNNING: [u8; 3] = [0x8F, 0xB8, 0xDE];
pub const CONFLICT: [u8; 3] = [0xC8, 0x9C, 0xE8];
/// The age, the keys, what is not reached, scheduled or cancelled.
pub const QUIET: [u8; 3] = [0x55, 0x52, 0x68];
/// The night the table sits in: dusky violet just under the header's
/// horizon, deepening over the first rows to the night below.
pub const DUSK: [u8; 3] = [0x1F, 0x15, 0x2C];
pub const NIGHT: [u8; 3] = [0x0C, 0x0A, 0x13];
/// A key's cap in the footer, and the key printed on it.
pub const CAP: [u8; 3] = [0x26, 0x21, 0x38];
pub const KEY: [u8; 3] = [0xCF, 0xC8, 0xE8];
/// The one deep block when its row needs you, and the colour it breathes up to.
pub const WINE: [u8; 3] = [0x2E, 0x14, 0x1A];
pub const WINE_BREATH: [u8; 3] = [0x46, 0x1E, 0x28];
/// The block when its row is only where the cursor is, and the colour it breathes up to.
pub const INDIGO: [u8; 3] = [0x1D, 0x1B, 0x36];
pub const INDIGO_BREATH: [u8; 3] = [0x29, 0x26, 0x4A];

/// The firefly an all-green board gets, at its brightest and its dimmest:
/// a teal from the header, no brighter than a passed branch's name.
pub const FIREFLY: [u8; 3] = [0x34, 0x58, 0x50];
pub const FIREFLY_LOW: [u8; 3] = [0x14, 0x22, 0x20];

/// How much of its brightness a passed row keeps.
const PALE_PERCENT: u16 = 38;

/// `colour` at a passed row's brightness, its hue kept.
#[must_use]
pub fn pale(colour: [u8; 3]) -> [u8; 3] {
    colour.map(|c| u8::try_from(u16::from(c) * PALE_PERCENT / 100).unwrap_or(u8::MAX))
}

/// The colour `level` of the way from `from` to `to`, each channel rounded.
#[must_use]
pub fn blend(from: [u8; 3], to: [u8; 3], level: f64) -> [u8; 3] {
    std::array::from_fn(|i| byte((f64::from(from[i]) + (f64::from(to[i]) - f64::from(from[i])) * level) / 255.0))
}

/// Text in `colour`, which ratatui's `Stylize` makes bold or italic.
#[must_use]
pub fn ink(colour: [u8; 3]) -> Style {
    Style::new().fg(colour.into())
}
