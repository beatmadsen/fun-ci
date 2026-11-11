//! Hiding a branch or a daily or weekly job (design.md, The console): the
//! key that hides the row under the cursor or shows a hidden one again, the
//! question that asks how (snoozed, until its next run, or ignored, until
//! shown again), what the footer says of the rows hidden, and what a hidden
//! row says once the user asks to see them.

use super::footer::{Key, Offer};
use super::jobs;
use crate::format::project_name;
use crate::model::{Board, Hidden, Job, Run};

const HIDE: Key = ("h", "hide");
const SHOW: Key = ("h", "show");
const SNOOZE: Key = ("s", "snooze until its next run");
const IGNORE: Key = ("i", "ignore until shown again");

/// The answers' words where the footer has too little room to say how long a row stays hidden.
pub const BRIEFLY: [(Key, Key); 2] = [(SNOOZE, ("s", "snooze")), (IGNORE, ("i", "ignore"))];

/// The row under the cursor: a branch's run, or a job.
enum Under<'a> {
    Run(&'a Run),
    Job(&'a Job),
}

impl Under<'_> {
    fn hidden(&self) -> Option<Hidden> {
        match self {
            Under::Run(run) => run.hidden,
            Under::Job(job) => job.hidden,
        }
    }

    /// Its name as the question says it: after its project's when the board holds more than one.
    fn name(&self, board: &Board) -> String {
        let named = jobs::many_projects(board);
        match self {
            Under::Run(run) => match run.commit.project.as_deref() {
                Some(project) if named => format!("{} · {}", project_name(project), run.commit.branch),
                _ => run.commit.branch.clone(),
            },
            Under::Job(job) => jobs::name(job, named),
        }
    }
}

/// The key for the row under the cursor: `h hide`, or `h show` on a hidden one; none without a cursor.
#[must_use]
pub fn key(board: &Board) -> Option<Key> {
    under_cursor(board).map(|row| if row.hidden().is_some() { SHOW } else { HIDE })
}

/// The question naming the row the cursor would hide, and the keys that
/// answer it, while the footer asks.
#[must_use]
pub fn asked(board: &Board) -> Option<Offer> {
    let row = under_cursor(board).filter(|_| board.view.hiding)?;
    Some(Offer { question: Some(format!("Hide {}?", row.name(board))), keys: vec![SNOOZE, IGNORE, ("n", "no")] })
}

/// `a shows 2 hidden rows`; once they are shown, `a hides hidden rows`;
/// nothing when none is hidden, or while the footer asks a question, when
/// `a` does nothing.
#[must_use]
pub fn aside(board: &Board) -> String {
    asides(board)[0].clone()
}

/// What `aside` says, then in fewer words and fewer again, for a footer
/// with little room: `a shows 2 hidden`, `2 hidden`.
#[must_use]
pub fn asides(board: &Board) -> [String; 3] {
    let shown = board.runs.iter().any(|run| run.hidden.is_some()) || board.jobs.iter().any(|job| job.hidden.is_some());
    match board.hidden_rows {
        0 => Default::default(),
        _ if board.view.hiding || board.view.confirming => Default::default(),
        _ if shown => ["a hides hidden rows", "a hides hidden", "a hides"].map(str::to_string),
        1 => ["a shows 1 hidden row", "a shows 1 hidden", "1 hidden"].map(str::to_string),
        many => [format!("a shows {many} hidden rows"), format!("a shows {many} hidden"), format!("{many} hidden")],
    }
}

/// What a job hidden `how` says in place of what happened, briefly on a narrow screen.
#[must_use]
pub fn said(how: Hidden, brief: bool) -> &'static str {
    match how {
        Hidden::Snoozed if brief => "snoozed",
        Hidden::Snoozed => "snoozed until its next run",
        Hidden::Ignored => "ignored",
        Hidden::Otherwise => "hidden",
    }
}

fn under_cursor(board: &Board) -> Option<Under<'_>> {
    let run = board.runs.get(board.view.cursor?).map(Under::Run);
    run.or_else(|| jobs::lead(board).and_then(|index| board.jobs.get(index)).map(Under::Job))
}
