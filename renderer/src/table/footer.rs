//! The footer's words (design.md, The console): the keys that do something
//! now, each on a cap, or the question confirming a cancel and the keys that
//! answer it; what a short screen left out; and in the flat layout, where no
//! label can say it, which trunks are stale.

use ratatui::text::Line;

use super::line::placed;
use super::line::Part;
use super::night::{CAP, KEY, NOTE, QUIET, ink};
use super::jobs;
use super::columns::Columns;
use super::paint::fetched;
use super::{Drawn, Frame};
use crate::format::{columns, cut, project_name, short_sha};
use crate::model::{Board, JobStatus, Run};

/// The least space between the keys and what the footer says beside them.
const APART: usize = 5;

/// The space between one key's word and the next key's cap.
const BETWEEN: usize = 4;

/// A key and what it does: `("q", "quit")`.
pub type Key = (&'static str, &'static str);

const MOVE: Key = ("j/k", "move");
const CANCEL: Key = ("c", "cancel");
pub const QUIT: Key = ("q", "quit");

/// What the footer offers: the question it asks, if it asks one, and the keys.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Offer {
    pub question: Option<String>,
    pub keys: Vec<Key>,
}

/// The keys, `c cancel` among them only while a run is running or waits to
/// start, or a job runs; or the question naming the run or job the cursor
/// would cancel, `y` and `n`.
#[must_use]
pub fn keys(board: &Board) -> Offer {
    if let Some((name, sha)) = confirming(board) {
        let question = format!("Cancel {name} ({})?", short_sha(sha));
        return Offer { question: Some(question), keys: vec![("y", "yes"), ("n", "no")] };
    }
    let runs = board.runs.iter().any(|run| matches!(run.status(), "running" | "pending"));
    let cancellable = runs || board.jobs.iter().any(|job| job.status == JobStatus::Running);
    Offer { question: None, keys: if cancellable { vec![MOVE, CANCEL, QUIT] } else { vec![MOVE, QUIT] } }
}

/// `offer` from column `at`: the question, then each key on its cap with
/// its word beside it; and the column after it all.
#[must_use]
pub fn offered(offer: &Offer, at: usize) -> (Vec<Part>, usize) {
    let mut parts: Vec<Part> = offer.question.iter().map(|question| (at, question.clone(), ink(KEY))).collect();
    let mut next = offer.question.as_ref().map_or(at, |question| at + columns(question) + 2);
    for (key, word) in &offer.keys {
        parts.extend([(next, format!(" {key} "), ink(KEY).bg(CAP.into())), (next + columns(key) + 3, (*word).to_string(), ink(QUIET))]);
        next += columns(key) + 3 + columns(word) + BETWEEN;
    }
    (parts, next.saturating_sub(BETWEEN))
}

/// `2 passed not shown`, or nothing when nothing was left out.
#[must_use]
pub fn aside(unshown: usize) -> String {
    if unshown == 0 { String::new() } else { format!("{unshown} passed not shown") }
}

/// Each stale trunk with its project: `agent-tome: trunk last fetched 2h ago`.
#[must_use]
pub fn stale(board: &Board, now_ms: i64) -> String {
    let named = board.stale_trunks.iter().map(|trunk| format!("{}: {}", project_name(&trunk.project), fetched(trunk, now_ms)));
    named.collect::<Vec<_>>().join(" · ")
}

/// The name and commit of the run or job the cursor would cancel, while a cancel is being confirmed.
fn confirming(board: &Board) -> Option<(&str, &str)> {
    let index = board.view.cursor.filter(|_| board.view.confirming)?;
    let run = board.runs.get(index).map(|run: &Run| (run.commit.branch.as_str(), run.commit.sha.as_str()));
    run.or_else(|| jobs::lead(board).and_then(|at| board.jobs.get(at)).map(|job| (job.name.as_str(), job.sha.as_deref().unwrap_or_default())))
}

/// The command that says why the job under the cursor failed, when it needs you.
#[must_use]
pub fn why_job(board: &Board) -> Option<String> {
    let job = jobs::lead(board).and_then(|index| board.jobs.get(index)).filter(|job| jobs::needs_you(job))?;
    Some(format!("fun-ci why --job {}", job.name))
}

/// That command, when it fits whole beside the footer's keys on a screen
/// `width` wide laid out in `layout`. A command cut short is one that can't
/// be typed, so one that doesn't fit goes above the footer instead.
#[must_use]
pub fn why_job_beside(board: &Board, layout: Columns, width: usize) -> Option<String> {
    let (_, end) = offered(&keys(board), layout.label);
    why_job(board).filter(|command| end + APART + columns(command) + layout.margin <= width)
}

/// The footer: the keys where the labels start, and beside them, quieter,
/// the command that says why the job under the cursor failed if it fits, or
/// how many passed rows the screen was too short for, cut if it must be.
#[must_use]
pub fn footer_line(board: &Board, drawn: &Drawn, frame: Frame) -> Line<'static> {
    let width = usize::from(frame.width);
    let (mut parts, end) = offered(&keys(board), drawn.columns.label);
    let keys_end = end + APART;
    let said = why_job_beside(board, drawn.columns, width).unwrap_or_else(|| aside(drawn.unshown));
    let aside = cut(&said, width.saturating_sub(keys_end + drawn.columns.margin));
    let aside_at = width.saturating_sub(drawn.columns.margin + columns(&aside)).max(keys_end);
    parts.push((aside_at, aside, ink(NOTE).italic()));
    placed(parts)
}
