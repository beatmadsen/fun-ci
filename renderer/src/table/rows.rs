//! A branch's row as one phrase, name, four marks, what happened and when,
//! pale once it passed; and a project's passed branches on one line.

use super::line::Style;
use super::marks::marks;
use super::night::{BRANCH, CURSOR, FAILED, LABEL, PASSED, QUIET, RUNNING, TIMED_OUT, pale};
use super::paint::{Paint, Part};
use super::words::said;
use crate::format::{age, cut, project_name};
use crate::model::Run;

/// Room kept on a folded line for how many more it could not name, `3 more`.
const MORE: usize = 12;

/// The row of `run`: its name, bold in the cursor's colour when it leads,
/// its marks unless it was cancelled, what happened, and its age.
#[must_use]
pub fn row(run: &Run, paint: &Paint) -> Vec<Part> {
    let (columns, leads) = (paint.columns, paint.lead == Some(run.id));
    let tone = |colour: [u8; 3]| if run.status() == "passed" && !leads { pale(colour) } else { colour };
    let name = match run.status() {
        _ if leads => Style::bold(CURSOR),
        "cancelled" => Style::plain(QUIET),
        _ => Style::plain(tone(BRANCH)),
    };
    let mut parts = named(run, paint, name);
    if run.status() != "cancelled" {
        parts.extend(strip(run, paint, &tone));
    }
    let words = if run.status() == "cancelled" { Style::italic(QUIET) } else { Style::plain(tone(outcome(run))) };
    parts.push((columns.words, said(run, paint.frame.now_ms), words));
    parts.push((columns.age_end - 4, format!("{:>4}", when(run, paint)), Style::plain(tone(QUIET))));
    parts
}

/// The four marks, two columns apart, in the row's tone.
fn strip(run: &Run, paint: &Paint, tone: &dyn Fn([u8; 3]) -> [u8; 3]) -> Vec<Part> {
    let marks = marks(run, paint.frame.spinner).into_iter().enumerate();
    marks.map(|(i, (mark, colour))| (paint.columns.strip + 2 * i, mark.to_string(), Style::plain(tone(colour)))).collect()
}

/// The branch's name, after its project's in the flat layout, cut to its room.
fn named(run: &Run, paint: &Paint, style: Style) -> Vec<Part> {
    let columns = paint.columns;
    let Some(tag) = paint.tags else { return vec![(columns.branch, cut(&run.commit.branch, columns.name), style)] };
    let project = run.commit.project.as_deref().map(project_name).unwrap_or_default();
    let room = columns.name.saturating_sub(tag + 2).max(4);
    vec![(columns.branch, project, Style::plain(LABEL)), (columns.branch + tag + 2, cut(&run.commit.branch, room), style)]
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
    parts.push((paint.columns.words.max(at), "passed".to_string(), Style::plain(pale(PASSED))));
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

/// A folded branch's name, a space and its age.
fn wide(run: &Run, paint: &Paint) -> usize {
    run.commit.branch.chars().count() + 1 + when(run, paint).chars().count()
}

/// `3 more` at `at`, quietly, and where what follows it may start.
fn more(count: usize, at: usize) -> (Part, usize) {
    let text = format!("{count} more");
    let after = at + text.chars().count() + 5;
    ((at, text, Style::plain(pale(QUIET))), after)
}

/// A folded branch at `at`: its name pale, its age quieter beside it.
fn one_folded(run: &Run, paint: &Paint, at: usize) -> [Part; 2] {
    let name = run.commit.branch.clone();
    let age_at = at + name.chars().count() + 1;
    [(at, name, Style::plain(pale(BRANCH))), (age_at, when(run, paint), Style::plain(pale(QUIET)))]
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
