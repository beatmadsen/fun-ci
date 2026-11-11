//! Hiding a daily or weekly job (design.md, The console): the key that
//! hides the job under the cursor or shows a hidden one again, the question
//! that asks how (snoozed, until it runs again, or ignored, for good), what
//! the footer says of the jobs hidden, and what a hidden job's row says once
//! the user asks to see them.

use super::footer::{Key, Offer};
use super::jobs;
use crate::model::{Board, Hidden, Job};

const HIDE: Key = ("h", "hide");
const SHOW: Key = ("h", "show");

/// The key for the job under the cursor: `h hide`, or `h show` on a hidden one; none off a job.
#[must_use]
pub fn key(board: &Board) -> Option<Key> {
    under_cursor(board).map(|job| if job.hidden.is_some() { SHOW } else { HIDE })
}

/// The question naming the job the cursor would hide, and the keys that
/// answer it, while the footer asks.
#[must_use]
pub fn asked(board: &Board) -> Option<Offer> {
    let job = under_cursor(board).filter(|_| board.view.hiding)?;
    Some(Offer { question: Some(format!("Hide {}?", job.name)), keys: vec![("s", "snooze"), ("i", "ignore"), ("n", "no")] })
}

/// `a shows 2 hidden jobs`; once they are shown, `a hides hidden jobs`;
/// nothing when none is hidden, or while the footer asks a question, when
/// `a` does nothing. The key comes first, so a footer with little room
/// cuts the count, not the key.
#[must_use]
pub fn aside(board: &Board) -> String {
    let shown = board.jobs.iter().any(|job| job.hidden.is_some());
    match board.hidden_jobs {
        0 => String::new(),
        _ if board.view.hiding || board.view.confirming => String::new(),
        _ if shown => "a hides hidden jobs".to_string(),
        1 => "a shows 1 hidden job".to_string(),
        many => format!("a shows {many} hidden jobs"),
    }
}

/// What a job hidden `how` says in place of what happened, briefly on a narrow screen.
#[must_use]
pub fn said(how: Hidden, brief: bool) -> &'static str {
    match how {
        Hidden::Snoozed if brief => "snoozed",
        Hidden::Snoozed => "snoozed until it runs again",
        Hidden::Ignored => "ignored",
        Hidden::Otherwise => "hidden",
    }
}

fn under_cursor(board: &Board) -> Option<&Job> {
    jobs::lead(board).and_then(|index| board.jobs.get(index))
}
