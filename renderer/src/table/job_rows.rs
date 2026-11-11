//! A daily or weekly job's row as one phrase (design.md, Daily and weekly
//! jobs): its name, how often it runs, its mark, what happened and when,
//! pale once it passed; the section folded into one pale line; and the
//! section counted on one line for a short screen.

use ratatui::style::Style;

use super::job_words::{due_in, said, said_briefly};
use super::jobs::needs_you;
use super::night::{BRANCH, CURSOR, FAILED, LABEL, NOTE, PASSED, QUIET, RUNNING, TIMED_OUT, ink, pale};
use super::paint::{Paint, Part};
use crate::format::{age, columns as width_of, cut, project_name};
use crate::model::{Job, JobStatus};

/// The row of `job`, named `name`, bold in the cursor's colour when it
/// `leads`, its project's name cut to fit the column (`fitted`); pale once
/// it passed or while hidden, unless it leads, when a hidden job's mark is
/// as quiet as its words, so the mark alone doesn't say it needs you.
#[must_use]
pub fn row(job: &Job, name: &str, leads: bool, paint: &Paint) -> Vec<Part> {
    let columns = paint.columns;
    let name = fitted(job, name, columns.name);
    let quiet = job.status == JobStatus::Passed || job.hidden.is_some();
    let tone = |colour: [u8; 3]| if quiet && !leads { pale(colour) } else { colour };
    let style = if leads { ink(CURSOR).bold() } else { ink(tone(BRANCH)) };
    let (mark, colour) = mark(job, paint.frame.spinner);
    let mut parts = vec![
        (columns.branch, cut(&name, columns.name), style),
        (columns.strip, job.cadence.clone(), ink(tone(LABEL))),
        (columns.strip + MARK_AT, mark.to_string(), ink(if leads && job.hidden.is_some() { QUIET } else { tone(colour) })),
        (columns.words, words(job, paint), words_style(job, &tone)),
        (columns.age_end - 4, format!("{:>4}", job.updated_at.map(|at| age(at, paint.frame.now_ms)).unwrap_or_default()), ink(tone(QUIET))),
    ];
    parts.extend(accent(job).map(|colour| (columns.margin, "▌".to_string(), ink(colour))));
    parts
}

/// `name` (its project's, then its own) when it fits in `room`; else with
/// its project's name cut, since its own is the one that must stay whole,
/// to its first letter where that is all that fits; its own alone when not
/// even that fits.
fn fitted(job: &Job, name: &str, room: usize) -> String {
    let left = room.saturating_sub(width_of(&job.name) + width_of(" · "));
    match job.project.as_deref() {
        _ if width_of(name) <= room => name.to_string(),
        Some(project) if name != job.name && left > 0 => format!("{} · {}", shortened(&project_name(project), left), job.name),
        _ => job.name.clone(),
    }
}

/// `project` cut to `room`, or its first letter alone when `room` has no space for `…` beside one.
fn shortened(project: &str, room: usize) -> String {
    if room == 1 { project.chars().take(1).collect() } else { cut(project, room) }
}

/// Where a job's mark sits after the start of the marks' column: past `weekly`.
pub const MARK_AT: usize = 7;

/// What `job` says, briefly when the screen is narrow.
#[must_use]
pub fn words(job: &Job, paint: &Paint) -> String {
    if paint.brief { said_briefly(job, paint.frame.now_ms) } else { said(job, paint.frame.now_ms) }
}

fn words_style(job: &Job, tone: &dyn Fn([u8; 3]) -> [u8; 3]) -> Style {
    if job.status == JobStatus::Due || job.hidden.is_some() { ink(QUIET).italic() } else { ink(tone(outcome(job))) }
}

/// The stripe down the left of a job that needs you or is running, in the
/// colour of why; none for a job the user hid.
#[must_use]
pub fn accent(job: &Job) -> Option<[u8; 3]> {
    job.hidden.is_none().then(|| stripe(job)).flatten()
}

fn stripe(job: &Job) -> Option<[u8; 3]> {
    match job.status {
        JobStatus::Failed | JobStatus::Lost => Some(FAILED),
        JobStatus::Timeout => Some(TIMED_OUT),
        JobStatus::Running => Some(RUNNING),
        JobStatus::Due | JobStatus::Scheduled | JobStatus::Passed | JobStatus::Unknown => None,
    }
}

/// A job's mark, in a stage mark's shape and colour: `◌` while it is due.
fn mark(job: &Job, spinner: char) -> (char, [u8; 3]) {
    match job.status {
        JobStatus::Passed => ('✓', PASSED),
        JobStatus::Failed | JobStatus::Lost => ('◆', FAILED),
        JobStatus::Timeout => ('◇', TIMED_OUT),
        JobStatus::Running => (spinner, RUNNING),
        JobStatus::Scheduled => ('◔', QUIET),
        JobStatus::Due | JobStatus::Unknown => ('◌', QUIET),
    }
}

fn outcome(job: &Job) -> [u8; 3] {
    match job.status {
        JobStatus::Passed => PASSED,
        JobStatus::Failed | JobStatus::Lost => FAILED,
        JobStatus::Timeout => TIMED_OUT,
        JobStatus::Running => RUNNING,
        JobStatus::Due | JobStatus::Scheduled | JobStatus::Unknown => QUIET,
    }
}

/// The quiet section on one pale line: a tick, how many passed and are
/// due, and which is due again soonest, `✓ 4 passed · mutation due in 6h`.
#[must_use]
pub fn folded(jobs: &[Job], paint: &Paint) -> Vec<Part> {
    let soonest = jobs.iter().filter(|job| job.due_at.is_some()).min_by_key(|job| job.due_at);
    let next = soonest.and_then(|job| due_in(job, paint.frame.now_ms).map(|when| format!(" · {} due in {when}", job.name)));
    let text = format!("{}{}", counts(jobs), next.unwrap_or_default());
    vec![(paint.columns.branch, "✓".to_string(), ink(pale(PASSED))), (paint.columns.branch + 2, text, ink(pale(PASSED)))]
}

/// The section on one line, `daily & weekly: 1 failed, 3 passed`, its
/// stripe in the colour of the job that most needs you.
#[must_use]
pub fn counted(jobs: &[Job], title: &str, paint: &Paint) -> Vec<Part> {
    let mut parts = vec![(paint.columns.label, format!("{title}: {}", counts(jobs)), ink(NOTE).italic())];
    let most = jobs.iter().find(|job| needs_you(job)).or_else(|| jobs.iter().find(|job| job.status == JobStatus::Running));
    parts.extend(most.and_then(accent).map(|colour| (paint.columns.margin, "▌".to_string(), ink(colour))));
    parts
}

/// How many jobs are in each state, most urgent first, and how many of
/// those shown are hidden ones: `1 failed, 3 passed, 1 hidden`.
fn counts(jobs: &[Job]) -> String {
    let states = [
        (JobStatus::Failed, "failed"),
        (JobStatus::Lost, "stopped"),
        (JobStatus::Timeout, "ran out of time"),
        (JobStatus::Running, "running"),
        (JobStatus::Due, "due"),
        (JobStatus::Passed, "passed"),
        (JobStatus::Unknown, "unknown"),
    ];
    let count = |status: &JobStatus| jobs.iter().filter(|job| job.status == *status && job.hidden.is_none()).count();
    let hidden = jobs.iter().filter(|job| job.hidden.is_some()).count();
    let counted = states.iter().map(|(status, word)| (count(status), *word)).chain([(hidden, "hidden")]);
    counted.filter(|(count, _)| *count > 0).map(|(count, word)| format!("{count} {word}")).collect::<Vec<_>>().join(", ")
}
