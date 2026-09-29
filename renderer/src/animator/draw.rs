//! Where each animation lands on the screen.

use super::effect::Effect;
use super::footer::footer_overlay;
use super::header::HEADER_HEIGHT;
use super::overlay::{stage_overlay, stage_text};
use crate::model::Run;
use crate::screen::Screen;
use crate::table::layout::Layout;

/// The screen row of the table's first run, under the header, a blank line and the stages' names.
pub const FIRST_RUN_ROW: usize = HEADER_HEIGHT + 3;

/// Each effect over its stage's cell, on its run's row.
pub fn stages(screen: &mut Screen, effects: &[Effect], runs: &[Run]) {
    let layout = Layout::fit(runs, screen.width());
    for (row, col, text) in effects.iter().filter_map(|effect| placed(effect, runs, &layout)) {
        screen.write_at(row, col, &text);
    }
}

/// The footer banner of the most important effect that has one, on the line
/// below the last run.
pub fn footer(screen: &mut Screen, effects: &[Effect], runs: &[Run]) {
    let banner = most_important(effects).and_then(|effect| footer_overlay(effect, screen.width(), runs));
    if let Some(text) = banner {
        screen.write_at(FIRST_RUN_ROW + runs.len(), 1, &format!("{text}\u{1b}[K"));
    }
}

fn placed(effect: &Effect, runs: &[Run], layout: &Layout) -> Option<(usize, usize, String)> {
    let index = runs.iter().position(|run| run.id == effect.run_id)?;
    let overlay = stage_overlay(effect, &stage_text(&runs[index], &effect.stage, layout)?)?;
    Some((FIRST_RUN_ROW + index, layout.stage_column(&effect.stage)? + 1, overlay))
}

fn most_important(effects: &[Effect]) -> Option<&Effect> {
    let candidates = effects.iter().filter(|e| e.kind.has_footer());
    candidates.fold(None, |best: Option<&Effect>, e| match best {
        Some(b) if b.kind.priority() >= e.kind.priority() => Some(b),
        _ => Some(e),
    })
}
