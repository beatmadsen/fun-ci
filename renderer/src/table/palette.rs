//! The table's colours, one per meaning (docs/tui-rubric.md, Palette): a
//! state's colour is used for that state alone, magenta for a conflict with
//! the trunk alone, and names and times in greys that belong to no state.

pub const PASSED: [u8; 3] = [0x5F, 0xD3, 0x8D];
pub const FAILED: [u8; 3] = [0xFF, 0x5F, 0x5F];
pub const TIMED_OUT: [u8; 3] = [0xFF, 0xB5, 0x47];
pub const RUNNING: [u8; 3] = [0x4F, 0xD6, 0xE8];
/// The running bar's other beat.
pub const RUNNING_LOW: [u8; 3] = [0x1E, 0x5A, 0x62];
pub const CONFLICT: [u8; 3] = [0xE2, 0x7C, 0xF5];

pub const TEXT: [u8; 3] = [0xC9, 0xCE, 0xD6];
pub const SECONDARY: [u8; 3] = [0x8A, 0x91, 0x9E];
pub const FAINT: [u8; 3] = [0x4B, 0x51, 0x5C];
/// The SHA and the age: receding, yet readable on a band.
pub const QUIET: [u8; 3] = [0x6E, 0x75, 0x82];

/// Bands mark trouble alone, darkly, so the text on them stays at full strength.
pub const FAILED_TINT: [u8; 3] = [0x3A, 0x15, 0x19];
pub const TIMED_OUT_TINT: [u8; 3] = [0x33, 0x27, 0x11];
pub const SELECTED: [u8; 3] = [0x1D, 0x27, 0x33];
/// The cursor's mark, and the branch under it.
pub const CURSOR: [u8; 3] = [0xFF, 0xFF, 0xFF];

/// How much of its brightness a colour keeps on a run a newer one replaced.
const DIMMED_PERCENT: u16 = 60;
/// How much the cursor lifts each channel of a tinted row: enough to see,
/// never so much the row outshines a failure.
const SELECTED_LIFT: u8 = 20;

/// `colour` at the brightness of a run a newer one replaced, its hue kept.
#[must_use]
pub fn dimmed(colour: [u8; 3]) -> [u8; 3] {
    colour.map(|c| u8::try_from(u16::from(c) * DIMMED_PERCENT / 100).unwrap_or(u8::MAX))
}

/// A row's tint with the cursor on it: a little lighter, still its own hue.
#[must_use]
pub fn selected(tint: Option<[u8; 3]>) -> [u8; 3] {
    tint.map_or(SELECTED, |t| t.map(|c| c.saturating_add(SELECTED_LIFT)))
}
