//! The banner an effect shows in the footer: four looks, each held for eight
//! frames, blank at either end.

use super::effect::{Effect, Kind};
use crate::ansi::RESET;

const HOLD: usize = 8;

/// The footer line `effect` shows this frame, if any.
#[must_use]
pub fn footer_overlay(effect: &Effect, width: u16) -> Option<String> {
    let (colour, text) = look(effect)?;
    let pad = usize::from(width).saturating_sub(text.chars().count()) / 2;
    Some(format!("{}\u{1b}[{colour}m{text}{RESET}", " ".repeat(pad)))
}

fn look(effect: &Effect) -> Option<(&'static str, String)> {
    match effect.kind {
        Kind::Failure => failure_look(effect.frame / HOLD, &effect.stage),
        Kind::Success => success_look(effect.frame / HOLD),
        Kind::Timeout | Kind::StagePass => None,
    }
}

fn failure_look(look: usize, stage: &str) -> Option<(&'static str, String)> {
    let (up, down) = (stage.to_uppercase(), stage.to_lowercase());
    match look {
        1 => Some(("1;31", format!(">>> {up} FAILED <<<"))),
        2 => Some(("31", format!(">> {down} failed <<"))),
        3 => Some(("2;31", format!("> {down} failed <"))),
        _ => None,
    }
}

fn success_look(look: usize) -> Option<(&'static str, String)> {
    match look {
        1 => Some(("1;32", "* * * NICE! * * *".to_string())),
        2 => Some(("32", ". + . * NICE! * . + .".to_string())),
        3 => Some(("2;32", "' . + .  nice  . + . '".to_string())),
        _ => None,
    }
}
