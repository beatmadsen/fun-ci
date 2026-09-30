//! A branch's row as one phrase, name, four marks, what happened and when,
//! pale once it passed; and a project's passed branches on one line.

use ratatui::style::Style;

use super::marks::{links, marks};
use super::night::{BRANCH, CONFLICT, CURSOR, FAILED, LABEL, PASSED, QUIET, RUNNING, TIMED_OUT, ink, pale};
use super::stack::conflicts;
use super::paint::{Paint, Part};
use super::words::phrase;
use crate::format::{age, columns, cut, project_name};
use crate::model::Run;

/// Room kept on a folded line for how many more it could not name, `3 more`.
const MORE: usize = 12;
/// The tick before a folded branch's name, and the space after it.
const TICK: usize = 2;

/// The row of `run`: its name, bold in the cursor's colour when it leads,
/// its marks unless it was cancelled, what happened, and its age.
#[must_use]
pub fn row(run: &Run, paint: &Paint) -> Vec<Part> {
    let (columns, leads) = (paint.columns, paint.lead == Some(run.id));
    let tone = |colour: [u8; 3]| if run.status() == "passed" && !leads { pale(colour) } else { colour };
    let mut parts = named(run, paint, name_style(run, leads, &tone));
    parts.extend(accent(run).map(|colour| (columns.margin, "▌".to_string(), ink(colour))));
    if run.status() != "cancelled" {
        parts.extend(strip(run, paint, &tone));
    }
    let words = if run.status() == "cancelled" { ink(QUIET).italic() } else { ink(tone(outcome(run))) };
    parts.push((columns.words, phrase(run, paint.frame.now_ms, paint.brief), words));
    parts.push((columns.age_end - 4, format!("{:>4}", when(run, paint)), ink(tone(QUIET))));
    parts
}

/// A row's name: bold in the cursor's colour when it leads, quiet once cancelled, else in the row's tone.
fn name_style(run: &Run, leads: bool, tone: &dyn Fn([u8; 3]) -> [u8; 3]) -> Style {
    match run.status() {
        _ if leads => ink(CURSOR).bold(),
        "cancelled" => ink(QUIET),
        _ => ink(tone(BRANCH)),
    }
}

/// The stripe down the left of a row that needs you or is running, in the colour of why.
#[must_use]
pub fn accent(run: &Run) -> Option<[u8; 3]> {
    match run.status() {
        "failed" => Some(FAILED),
        "timeout" => Some(TIMED_OUT),
        _ if conflicts(run) => Some(CONFLICT),
        "running" => Some(RUNNING),
        _ => None,
    }
}

/// The four marks, two columns apart with a link between each, in the row's tone.
fn strip(run: &Run, paint: &Paint, tone: &dyn Fn([u8; 3]) -> [u8; 3]) -> Vec<Part> {
    let marks = marks(run, paint.frame.spinner);
    let track = marks.iter().enumerate().map(|(i, mark)| (2 * i, *mark)).chain(links(&marks).into_iter().enumerate().map(|(i, link)| (2 * i + 1, link)));
    track.map(|(at, (mark, colour))| (paint.columns.strip + at, mark.to_string(), ink(tone(colour)))).collect()
}

/// The branch's name, after its project's in the flat layout, cut to its room.
fn named(run: &Run, paint: &Paint, style: Style) -> Vec<Part> {
    let columns = paint.columns;
    let Some(tag) = paint.tags else { return vec![(columns.branch, cut(&run.commit.branch, columns.name), style)] };
    let project = run.commit.project.as_deref().map(project_name).unwrap_or_default();
    let room = columns.name.saturating_sub(tag + 2).max(4);
    vec![(columns.branch, project, ink(LABEL)), (columns.branch + tag + 2, cut(&run.commit.branch, room), style)]
}

/// Passed branches on one line, each name pale with its age beside it, as
/// many as fit whole before the right margin and then how many more;
/// `passed` after them.
#[must_use]
pub fn folded(runs: &[&Run], paint: &Paint) -> Vec<Part> {
    let starts = starts(runs, paint);
    let mut parts: Vec<Part> = runs.iter().zip(&starts).flat_map(|(run, at)| one_folded(run, paint, *at)).collect();
    let last = starts.len().checked_sub(1).map(|i| starts[i] + wide(runs[i], paint) + 5);
    let mut at = last.unwrap_or(paint.columns.branch);
    if starts.len() < runs.len() {
        let (count, after) = more(runs.len() - starts.len(), at);
        parts.push(count);
        at = after;
    }
    parts.push((paint.columns.words.max(at), "passed".to_string(), ink(pale(PASSED))));
    parts
}

/// Where each branch that fits starts, leaving room for how many more after all but the last.
fn starts(runs: &[&Run], paint: &Paint) -> Vec<usize> {
    let end = usize::from(paint.frame.width).saturating_sub(paint.columns.margin + MORE);
    let mut at = paint.columns.branch;
    let fitting = |(i, run): (usize, &&Run)| {
        let (start, width) = (at, wide(run, paint));
        at += width + 5;
        (start + width + if i + 1 < runs.len() { MORE } else { 0 } <= end).then_some(start)
    };
    runs.iter().enumerate().map_while(fitting).collect()
}

/// A folded branch's tick, its name, a space and its age.
fn wide(run: &Run, paint: &Paint) -> usize {
    TICK + columns(&run.commit.branch) + 1 + columns(&when(run, paint))
}

/// `3 more` at `at`, quietly, and where what follows it may start.
fn more(count: usize, at: usize) -> (Part, usize) {
    let text = format!("{count} more");
    let after = at + columns(&text) + 5;
    ((at, text, ink(pale(QUIET))), after)
}

/// A folded branch at `at`: a pale tick, its name pale, its age quieter beside it.
fn one_folded(run: &Run, paint: &Paint, at: usize) -> [Part; 3] {
    let name = run.commit.branch.clone();
    let age_at = at + TICK + columns(&name) + 1;
    [(at, "✓".to_string(), ink(pale(PASSED))), (at + TICK, name, ink(pale(BRANCH))), (age_at, when(run, paint), ink(pale(QUIET)))]
}

fn when(run: &Run, paint: &Paint) -> String {
    age(run.state.updated_at, paint.frame.now_ms)
}

/// The colour of what a run says happened.
fn outcome(run: &Run) -> [u8; 3] {
    match run.status() {
        "passed" => PASSED,
        "failed" => FAILED,
        "timeout" => TIMED_OUT,
        "running" => RUNNING,
        _ => QUIET,
    }
}
