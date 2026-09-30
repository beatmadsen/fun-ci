//! Where each animation lands on the screen: a stage's effect over its mark
//! on its run's row, and an effect's banner on the line under the table,
//! both where the table put them (`Places`).

use super::effect::Effect;
use super::footer::footer_overlay;
use super::overlay::{stage_overlay, stage_text};
use crate::model::Run;
use crate::screen::Screen;
use crate::table::STAGES;

/// Where the table put things this frame, 1-based: each run's row, the
/// column of its first mark, and the line under the table; and the run whose
/// row is in the block, with the escape that paints the block's colour.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Places {
    pub rows: Vec<(u64, usize)>,
    pub strip: usize,
    pub banner: usize,
    pub block: Option<(u64, String)>,
}

/// Each effect over its stage's mark, on its run's row.
pub fn stages(screen: &mut Screen, effects: &[Effect], (runs, places): (&[Run], &Places)) {
    for (row, col, text) in effects.iter().filter_map(|effect| placed(effect, runs, places)) {
        screen.write_at(row, col, &text);
    }
}

/// The banner of the most important effect that has one, on the line under the table.
pub fn footer(screen: &mut Screen, effects: &[Effect], (runs, places): (&[Run], &Places)) {
    let banner = most_important(effects).and_then(|effect| footer_overlay(effect, screen.width(), runs));
    if let Some(text) = banner.filter(|_| places.banner > 0) {
        screen.write_at(places.banner, 1, &format!("{text}\u{1b}[K"));
    }
}

fn placed(effect: &Effect, runs: &[Run], places: &Places) -> Option<(usize, usize, String)> {
    let run = runs.iter().find(|run| run.id == effect.run_id)?;
    let row = places.rows.iter().find(|(id, _)| *id == effect.run_id)?.1;
    let index = STAGES.iter().position(|stage| *stage == effect.stage)?;
    let overlay = stage_overlay(effect, &stage_text(run, &effect.stage)?)?;
    let paper = places.block.as_ref().filter(|(id, _)| *id == run.id).map_or("", |(_, escape)| escape.as_str());
    Some((row, places.strip + 2 * index, format!("{paper}{overlay}")))
}

fn most_important(effects: &[Effect]) -> Option<&Effect> {
    let candidates = effects.iter().filter(|e| e.kind.has_footer());
    candidates.fold(None, |best: Option<&Effect>, e| match best {
        Some(b) if b.kind.priority() >= e.kind.priority() => Some(b),
        _ => Some(e),
    })
}
