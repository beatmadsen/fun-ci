//! A daily or weekly job's row as one phrase (design.md, Daily and weekly
//! jobs): its name, how often it runs, its mark, what happened and when,
//! pale once it passed; the section folded into one pale line; and the
//! section counted on one line for a short screen.

use ratatui::style::Style;

use super::job_words::{due_in, said, said_briefly};
use super::jobs::needs_you;
use super::night::{BRANCH, CURSOR, FAILED, LABEL, NOTE, PASSED, QUIET, RUNNING, TIMED_OUT, ink, pale};
use super::paint::{Paint, Part};
use crate::format::{age, cut};
use crate::model::Job;

/// The row of `job`, named `name`, bold in the cursor's colour when it `leads`.
#[must_use]
pub fn row(job: &Job, name: &str, leads: bool, paint: &Paint) -> Vec<Part> {
    let columns = paint.columns;
    let tone = |colour: [u8; 3]| if job.status == "passed" && !leads { pale(colour) } else { colour };
    let style = if leads { ink(CURSOR).bold() } else { ink(tone(BRANCH)) };
    let (mark, colour) = mark(job, paint.frame.spinner);
    let mut parts = vec![
        (columns.branch, cut(name, columns.name), style),
        (columns.strip, job.cadence.clone(), ink(tone(LABEL))),
        (columns.strip + MARK_AT, mark.to_string(), ink(tone(colour))),
        (columns.words, words(job, paint), words_style(job, &tone)),
        (columns.age_end - 4, format!("{:>4}", job.updated_at.map(|at| age(at, paint.frame.now_ms)).unwrap_or_default()), ink(tone(QUIET))),
    ];
    parts.extend(accent(job).map(|colour| (columns.margin, "▌".to_string(), ink(colour))));
    parts
}

/// Where a job's mark sits after the start of the marks' column: past `weekly`.
pub const MARK_AT: usize = 7;

/// What `job` says, briefly when the screen is narrow.
#[must_use]
pub fn words(job: &Job, paint: &Paint) -> String {
    if paint.brief { said_briefly(job, paint.frame.now_ms) } else { said(job, paint.frame.now_ms) }
}

fn words_style(job: &Job, tone: &dyn Fn([u8; 3]) -> [u8; 3]) -> Style {
    if job.status == "due" { ink(QUIET).italic() } else { ink(tone(outcome(job))) }
}

/// The stripe down the left of a job that needs you or is running, in the colour of why.
#[must_use]
pub fn accent(job: &Job) -> Option<[u8; 3]> {
    match job.status.as_str() {
        "failed" | "lost" => Some(FAILED),
        "timeout" => Some(TIMED_OUT),
        "running" => Some(RUNNING),
        _ => None,
    }
}

/// A job's mark, in a stage mark's shape and colour: `◌` while it is due.
fn mark(job: &Job, spinner: char) -> (char, [u8; 3]) {
    match job.status.as_str() {
        "passed" => ('✓', PASSED),
        "failed" | "lost" => ('◆', FAILED),
        "timeout" => ('◇', TIMED_OUT),
        "running" => (spinner, RUNNING),
        _ => ('◌', QUIET),
    }
}

fn outcome(job: &Job) -> [u8; 3] {
    match job.status.as_str() {
        "passed" => PASSED,
        "failed" | "lost" => FAILED,
        "timeout" => TIMED_OUT,
        "running" => RUNNING,
        _ => QUIET,
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
    let most = jobs.iter().find(|job| needs_you(job)).or_else(|| jobs.iter().find(|job| job.status == "running"));
    parts.extend(most.and_then(accent).map(|colour| (paint.columns.margin, "▌".to_string(), ink(colour))));
    parts
}

/// How many jobs are in each state, most urgent first: `1 failed, 3 passed`.
fn counts(jobs: &[Job]) -> String {
    let states = [("failed", "failed"), ("lost", "stopped"), ("timeout", "ran out of time"), ("running", "running"), ("due", "due"), ("passed", "passed")];
    let count = |status: &str| jobs.iter().filter(|job| job.status == status).count();
    let said: Vec<String> = states.iter().filter(|(status, _)| count(status) > 0).map(|(status, word)| format!("{} {word}", count(status))).collect();
    said.join(", ")
}
