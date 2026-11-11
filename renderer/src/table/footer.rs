//! The footer's words (design.md, The console): the keys that do something
//! now, each on a cap, or a question (confirming a cancel, or how to hide a
//! job: `hiding`) and the keys that answer it; what a short screen left out
//! and how many jobs are hidden; and in the flat layout, where no label can
//! say it, which trunks are stale.

use ratatui::text::Line;

use super::line::placed;
use super::line::Part;
use super::night::{CAP, KEY, NOTE, QUIET, ink};
use super::{hiding, jobs};
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
/// start, or a job runs, and `h` only while the cursor is on a job; or the
/// question naming the run or job the cursor would cancel, `y` and `n`; or
/// the one asking how to hide the job under the cursor (`hiding`).
#[must_use]
pub fn keys(board: &Board) -> Offer {
    if let Some((name, sha)) = confirming(board) {
        let question = format!("Cancel {name} ({})?", short_sha(sha));
        return Offer { question: Some(question), keys: vec![("y", "yes"), ("n", "no")] };
    }
    hiding::asked(board).unwrap_or_else(|| Offer { question: None, keys: acting(board) })
}

/// The keys that do something now.
fn acting(board: &Board) -> Vec<Key> {
    let runs = board.runs.iter().any(|run| matches!(run.status(), "running" | "pending"));
    let cancellable = runs || board.jobs.iter().any(|job| matches!(job.status, JobStatus::Running | JobStatus::Scheduled));
    [Some(MOVE), cancellable.then_some(CANCEL), hiding::key(board), Some(QUIT)].into_iter().flatten().collect()
}

/// `offer` in the `room` it has from column `at`: a question too long for
/// its keys to fit after it is cut, since a key cut short answers nothing.
#[must_use]
pub fn fitted(offer: Offer, at: usize, room: usize) -> Offer {
    let over = offered(&offer, at).1.saturating_sub(room);
    let question = offer.question.map(|question| cut(&question, columns(&question).saturating_sub(over)));
    Offer { question, ..offer }
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
    unshown_said(unshown)[0].clone()
}

/// What `aside` says, then in fewer words and fewer again: `2 not shown`, `+2`.
fn unshown_said(unshown: usize) -> [String; 3] {
    if unshown == 0 { Default::default() } else { [format!("{unshown} passed not shown"), format!("{unshown} not shown"), format!("+{unshown}")] }
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

/// The command that says why the job under the cursor failed, when it needs
/// you; not while the footer asks how to hide that job.
#[must_use]
pub fn why_job(board: &Board) -> Option<String> {
    let lead = jobs::lead(board).filter(|_| !board.view.hiding);
    let job = lead.and_then(|index| board.jobs.get(index)).filter(|job| jobs::needs_you(job))?;
    Some(format!("fun-ci why --job {}", job.name))
}

/// That command, when it fits whole beside the footer's keys on a screen
/// `width` wide laid out in `layout`, with all it says of the `unshown`
/// passed rows and the hidden jobs after it. A command cut short is one that
/// can't be typed, so one that doesn't fit goes above the footer instead.
#[must_use]
pub fn why_job_beside(board: &Board, layout: Columns, width: usize, unshown: usize) -> Option<String> {
    let (_, end) = offered(&keys(board), layout.label);
    let [said, ..] = asides(board, unshown);
    why_job(board).map(|command| joined([command, said])).filter(|beside| end + APART + columns(beside) + layout.margin <= width)
}

/// What the footer says beside its keys, in fewer words at each step: how
/// many passed rows the screen was too short for, then how many jobs are hidden.
fn asides(board: &Board, unshown: usize) -> [String; 3] {
    let (passed, hidden) = (unshown_said(unshown), hiding::asides(board));
    [0, 1, 2].map(|at| joined([passed[at].clone(), hidden[at].clone()]))
}

/// What is said, the empty left out, one after the other.
fn joined(said: [String; 2]) -> String {
    said.into_iter().filter(|said| !said.is_empty()).collect::<Vec<_>>().join(" · ")
}

/// The footer: the keys where the labels start, and beside them, quieter,
/// the command that says why the job under the cursor failed if it fits,
/// and how many passed rows the screen was too short for and how many jobs
/// are hidden, in as many words as fit, cut only when the fewest don't.
#[must_use]
pub fn footer_line(board: &Board, drawn: &Drawn, frame: Frame) -> Line<'static> {
    let width = usize::from(frame.width);
    let offer = fitted(keys(board), drawn.columns.label, width.saturating_sub(drawn.columns.margin));
    let (mut parts, end) = offered(&offer, drawn.columns.label);
    let keys_end = end + APART;
    let room = width.saturating_sub(keys_end + drawn.columns.margin);
    let said = why_job_beside(board, drawn.columns, width, drawn.unshown).unwrap_or_else(|| briefest_fitting(asides(board, drawn.unshown), room));
    let aside = cut(&said, room);
    let aside_at = width.saturating_sub(drawn.columns.margin + columns(&aside)).max(keys_end);
    parts.push((aside_at, aside, ink(NOTE).italic()));
    placed(parts)
}

/// The longest of `said` that fits in `room`, or the briefest.
fn briefest_fitting(said: [String; 3], room: usize) -> String {
    let [longest, fewer, fewest] = said;
    [longest, fewer].into_iter().find(|said| columns(said) <= room).unwrap_or(fewest)
}
