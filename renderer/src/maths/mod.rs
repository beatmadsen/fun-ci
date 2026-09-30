//! Numbers shared by what draws the table and what draws the animations,
//! each the same on every machine: the portable transcendental functions
//! (`portable`), counts as floats, and channels as bytes.

pub mod portable;

pub use portable::Portable;

/// A count, a position or a size as a float.
#[must_use]
pub fn float(n: usize) -> f64 {
    f64::from(u32::try_from(n).unwrap_or(u32::MAX))
}

/// The byte nearest `channel` scaled to 0-255.
#[must_use]
pub fn byte(channel: f64) -> u8 {
    let scaled = (channel.clamp(0.0, 1.0) * 255.0).round();
    u8::try_from(LEVELS.partition_point(|level| *level < scaled)).unwrap_or(u8::MAX)
}

static LEVELS: std::sync::LazyLock<Vec<f64>> = std::sync::LazyLock::new(|| (0u8..=255).map(f64::from).collect());
