//! How an effect restyles the mark of its stage, frame by frame. The mark is
//! whatever the table drew there; an effect changes only how it looks, over
//! the paper behind it.

use ratatui::buffer::Cell;
use ratatui::style::{Color, Modifier};

use super::effect::{Effect, Kind};

/// A colour, bold or not, and a background of its own if it has one.
type Look = (Color, Modifier, Option<Color>);

const BOLD: Modifier = Modifier::BOLD;
const PLAIN: Modifier = Modifier::empty();

const STAGE_PASS: [Look; 3] = [(Color::Yellow, BOLD, None), (Color::Green, BOLD, None), (Color::Green, PLAIN, None)];
const TIMEOUT: [Look; 4] = [(Color::Yellow, BOLD, None), (Color::Yellow, PLAIN, None), (Color::Yellow, BOLD, None), (Color::Yellow, PLAIN, None)];
/// A failed stage's cell flares red and cools, frame by frame, then shows as the row draws it.
const FAILURE_GLOW: [Look; 6] = [
    (Color::White, BOLD, Some(Color::Indexed(196))),
    (Color::White, BOLD, Some(Color::Indexed(160))),
    (Color::White, BOLD, Some(Color::Indexed(124))),
    (Color::LightRed, BOLD, Some(Color::Indexed(88))),
    (Color::LightRed, BOLD, Some(Color::Indexed(52))),
    (Color::LightRed, BOLD, None),
];

/// Restyles `cell`, the mark of `effect`'s stage, as the effect shows it this frame.
pub fn restyle(effect: &Effect, cell: &mut Cell) {
    if let Some((fg, modifier, bg)) = look(effect) {
        cell.fg = fg;
        cell.modifier = modifier;
        cell.bg = bg.unwrap_or(cell.bg);
    }
}

fn look(effect: &Effect) -> Option<Look> {
    match effect.kind {
        Kind::StagePass => Some(held(effect.frame, &STAGE_PASS)),
        Kind::Timeout => Some(held(effect.frame, &TIMEOUT)),
        Kind::Failure => FAILURE_GLOW.get(effect.frame).copied(),
        Kind::Success => sparkle(effect),
        Kind::Conflict => None,
    }
}

/// The look for `frame`, the last one held once they run out.
fn held(frame: usize, looks: &[Look]) -> Look {
    looks[frame.min(looks.len() - 1)]
}

/// A spark on the mark when its turn in the stagger comes, green after it.
fn sparkle(effect: &Effect) -> Option<Look> {
    match effect.frame.checked_sub(stagger(&effect.stage))? {
        0 => Some((Color::Yellow, BOLD, None)),
        1 => Some((Color::Green, PLAIN, None)),
        _ => None,
    }
}

fn stagger(stage: &str) -> usize {
    match stage {
        "build" => 2,
        "fast" => 4,
        "slow" => 6,
        _ => 0,
    }
}
