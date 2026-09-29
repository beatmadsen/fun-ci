//! One run's line: the gutter, SHA, branch and its conflict, project, the
//! four stage cells, the outcome and the age, each in its column.

use super::Frame;
use super::layout::{Layout, PROJECT_SHORT, STAGES, branch_tail, conflict_marker, folded_count};
use super::line::{Line, Style};
use super::palette::{self, CONFLICT, CURSOR, FAILED, FAINT, PASSED, QUIET, RUNNING, RUNNING_LOW, SECONDARY, TEXT, TIMED_OUT};
use super::stage_cell::stage_cell;
use super::tone::Tone;
use crate::format::{age, cut, project_name, short_sha};
use crate::model::Run;

/// How long each beat of a running run's bar lasts.
const PULSE_MS: u64 = 500;

/// Where a run stands on the board.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Place {
    pub newest: bool,
    pub selected: bool,
}

/// The line of `run`.
#[must_use]
pub fn run_line(run: &Run, layout: &Layout, place: Place, frame: Frame) -> Line {
    let (mut line, look) = blank_line(run, layout, place);
    let tone = look.tone;
    gutter(&mut line, run, place, frame.play_ms);
    identity(&mut line, run, layout, look);
    for stage in STAGES.iter().filter(|_| folded_count(run).is_none()) {
        let cell = stage_cell(run, stage, frame.spinner, frame.now_ms);
        let text: String = cell.text.chars().take(layout.cell()).collect();
        let style = Style { fg: tone.colour(cell.colour), bold: cell.bold && tone.bold() };
        line.put(layout.stage_column(stage).unwrap_or_default(), &text, style);
    }
    outcome(&mut line, run, layout, tone);
    line.put_right(layout.age_end(), &age(run.state.updated_at, frame.now_ms), Style::plain(look.quiet));
    line
}

/// How a row's names are drawn: its tone, whether the cursor is on it, and
/// the colour of its SHA and age, which a band would swallow if faint.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Look {
    tone: Tone,
    selected: bool,
    quiet: [u8; 3],
}

/// The row's empty line, as wide as the table and on its band, and how its names are drawn.
fn blank_line(run: &Run, layout: &Layout, place: Place) -> (Line, Look) {
    let tone = Tone::of(run, place.newest);
    let band = band(run, tone);
    let end = (layout.age_end() + 1).min(layout.width);
    let line = Line::new(end, if place.selected { Some(palette::selected(band)) } else { band });
    (line, Look { tone, selected: place.selected, quiet: if band.is_some() { SECONDARY } else { QUIET } })
}

/// A band across the row for trouble alone: a current failure or timeout.
fn band(run: &Run, tone: Tone) -> Option<[u8; 3]> {
    match (tone, run.status()) {
        (Tone::Current, "failed") => Some(palette::FAILED_TINT),
        (Tone::Current, "timeout") => Some(palette::TIMED_OUT_TINT),
        _ => None,
    }
}

/// A bar in the state's colour on the newest run of a branch, and the cursor's mark.
fn gutter(line: &mut Line, run: &Run, place: Place, play_ms: u64) {
    if let Some(colour) = bar(run, play_ms).filter(|_| place.newest) {
        line.put(0, "▌", Style::plain(colour));
    }
    if place.selected {
        line.put(1, "❯", Style::bold(CURSOR));
    }
}

fn bar(run: &Run, play_ms: u64) -> Option<[u8; 3]> {
    match run.status() {
        "passed" => Some(PASSED),
        "failed" => Some(FAILED),
        "timeout" => Some(TIMED_OUT),
        "running" => Some(if (play_ms / PULSE_MS).is_multiple_of(2) { RUNNING } else { RUNNING_LOW }),
        "pending" => Some(SECONDARY),
        _ => None,
    }
}

fn identity(line: &mut Line, run: &Run, layout: &Layout, look: Look) {
    if layout.sha {
        line.put(layout.sha_column(), short_sha(&run.commit.sha), Style::plain(look.quiet));
    }
    branch(line, run, layout, look);
    if layout.project > 0 {
        let name = project(run, layout.project);
        line.put(layout.project_column(), &name, Style::plain(look.tone.colour(SECONDARY)));
    }
}

/// The branch, cut to leave room for its conflict marker; bold white under the cursor.
fn branch(line: &mut Line, run: &Run, layout: &Layout, look: Look) {
    let tone = look.tone;
    let colour = if tone == Tone::Current { TEXT } else { tone.colour(SECONDARY) };
    let style = if look.selected { Style::bold(CURSOR) } else { Style::plain(colour) };
    let tail = branch_tail(run, layout.words);
    let room = layout.branch.saturating_sub(tail.as_ref().map_or(0, |m| m.chars().count() + 1)).max(1);
    let name = cut(&run.commit.branch, room);
    line.put(layout.branch_column(), &name, style);
    if let Some(tail) = tail {
        let at = layout.branch_column() + name.chars().count() + 1;
        let conflict = conflict_marker(run, layout.words).is_some();
        line.put(at, &tail, if conflict { Style { fg: tone.colour(CONFLICT), bold: tone.bold() } } else { Style::plain(FAINT) });
    }
}

/// The project's name in `room` columns: cut, or only its initial when that is all there is room for.
fn project(run: &Run, room: usize) -> String {
    let name = run.commit.project.as_deref().map(project_name).unwrap_or_default();
    if room == PROJECT_SHORT { name.chars().take(1).collect() } else { cut(&name, room) }
}

fn outcome(line: &mut Line, run: &Run, layout: &Layout, tone: Tone) {
    let (word, colour) = match run.status() {
        "passed" => ("PASSED", PASSED),
        "failed" => ("FAILED", FAILED),
        "timeout" => ("TIMED OUT", TIMED_OUT),
        "running" => ("RUNNING", RUNNING),
        "pending" => ("waiting", SECONDARY),
        _ => ("cancelled", FAINT),
    };
    let word = if tone == Tone::Current { word.to_string() } else { word.to_lowercase() };
    line.put(layout.outcome_column(), &word, Style { fg: tone.colour(colour), bold: tone.bold() });
}

