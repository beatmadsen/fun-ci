//! How an effect lights the mark of its stage: in a colour of its own that
//! fades, over a few tenths of a second, back to however the row draws the
//! mark, over whatever paper is under it. Each is a tachyonfx effect, and
//! each starts some time after the effect does, the first at once.

use ratatui::style::Color;
use tachyonfx::{Effect, Interpolation, fx};

use super::effect::Kind;

/// A stage that passed, lit as it happens.
pub const GOLD: [u8; 3] = [255, 205, 90];
/// A stage that ran out of time.
pub const AMBER: [u8; 3] = [255, 160, 60];
/// Behind a stage that failed, as it fails.
pub const FLARE: [u8; 3] = [215, 40, 50];
/// A failed stage's mark on the flare.
pub const WHITE: [u8; 3] = [255, 255, 255];

/// How long a stage's mark takes to fade back after passing, in milliseconds.
const PASS_MS: u32 = 300;
/// How long each of a timeout's two pulses takes.
const PULSE_MS: u32 = 200;
/// How long a failure's flare takes to cool.
const COOL_MS: u32 = 900;
/// How long after the run's last stage passes each stage's mark lights, in stage order.
const TURN_MS: u32 = 200;

/// The effects `kind` plays on `stage`'s mark, each with how many
/// milliseconds after the start it starts; a conflict with the trunk plays none.
#[must_use]
pub fn mark_effects(kind: Kind, stage: &str) -> Vec<(u64, Effect)> {
    match kind {
        Kind::StagePass => vec![(0, lit(GOLD, PASS_MS))],
        Kind::Timeout => vec![(0, lit(AMBER, PULSE_MS)), (u64::from(PULSE_MS), lit(AMBER, PULSE_MS))],
        Kind::Failure => vec![(0, fx::fade_from(rgb(WHITE), rgb(FLARE), (COOL_MS, Interpolation::QuadOut)))],
        Kind::Success => vec![(u64::from(turn(stage) * TURN_MS), lit(GOLD, PASS_MS))],
        Kind::Conflict => Vec::new(),
    }
}

/// The mark in `colour`, fading back to its own over `ms`.
fn lit(colour: [u8; 3], ms: u32) -> Effect {
    fx::fade_from_fg(rgb(colour), (ms, Interpolation::QuadOut))
}

/// Which turn `stage` takes, lint first.
fn turn(stage: &str) -> u32 {
    crate::model::STAGES.iter().position(|name| *name == stage).and_then(|at| u32::try_from(at).ok()).unwrap_or(0)
}

fn rgb([r, g, b]: [u8; 3]) -> Color {
    Color::Rgb(r, g, b)
}
