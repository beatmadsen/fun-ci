//! The banner an effect shows in the footer: four looks, each held for eight
//! frames, blank at either end.

use ratatui::style::{Color, Modifier, Style};

use super::effect::{Effect, Kind};
use crate::model::Run;

const HOLD: usize = 8;

/// The banner `effect` shows this frame, if any, and how; `runs` name a conflict's branch and trunk.
#[must_use]
pub fn banner(effect: &Effect, runs: &[Run]) -> Option<(String, Style)> {
    let (colour, weight, text) = look(effect, runs)?;
    Some((text, Style::default().fg(colour).add_modifier(weight)))
}

type Look = (Color, Modifier, String);

fn look(effect: &Effect, runs: &[Run]) -> Option<Look> {
    let (colour, text) = match effect.kind {
        Kind::Failure => (Color::Red, failure_text(effect.frame / HOLD, &effect.stage)?),
        Kind::Success => (Color::Green, success_text(effect.frame / HOLD)?),
        Kind::Conflict => (Color::Magenta, conflict_text(effect.frame / HOLD, &conflict(effect, runs)?)?),
        Kind::Timeout | Kind::StagePass => return None,
    };
    Some((colour, weight(effect.frame / HOLD), text))
}

/// Bold, then plain, then dim.
fn weight(look: usize) -> Modifier {
    match look {
        1 => Modifier::BOLD,
        3 => Modifier::DIM,
        _ => Modifier::empty(),
    }
}

/// "feat/search conflicts with main", from the run the effect is for.
fn conflict(effect: &Effect, runs: &[Run]) -> Option<String> {
    let run = runs.iter().find(|run| run.id == effect.run_id)?;
    Some(format!("{} conflicts with {}", run.commit.branch, run.trunk.as_ref()?.trunk))
}

fn conflict_text(look: usize, text: &str) -> Option<String> {
    match look {
        1 => Some(text.to_uppercase()),
        2 | 3 => Some(text.to_string()),
        _ => None,
    }
}

fn failure_text(look: usize, stage: &str) -> Option<String> {
    let (up, down) = (stage.to_uppercase(), stage.to_lowercase());
    match look {
        1 => Some(format!(">>> {up} FAILED <<<")),
        2 => Some(format!(">> {down} failed <<")),
        3 => Some(format!("> {down} failed <")),
        _ => None,
    }
}

fn success_text(look: usize) -> Option<String> {
    match look {
        1 => Some("* * * NICE! * * *".to_string()),
        2 => Some(". + . * NICE! * . + .".to_string()),
        3 => Some("' . + .  nice  . + . '".to_string()),
        _ => None,
    }
}
