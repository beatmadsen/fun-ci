//! The daily and weekly jobs below the table (design.md, Daily and weekly
//! jobs): a section of their own under the last project, one row a job, the
//! row under the cursor in the block. A quiet section, where nothing needs
//! you or runs, folds into one line; on a short screen the section gives up
//! its lines before any branch does, keeping one that counts the jobs until
//! that one would leave a branch off the screen.

use super::stack::Piece;
use crate::format::project_name;
use crate::model::{Board, Job, JobStatus};

/// The section's label, by the cadences of its jobs.
#[must_use]
pub fn title(jobs: &[Job]) -> &'static str {
    let has = |cadence: &str| jobs.iter().any(|job| job.cadence == cadence);
    match (has("daily"), has("weekly")) {
        (true, false) => "daily",
        (false, true) => "weekly",
        _ => "daily & weekly",
    }
}

/// The ways the section can be drawn, most room first: its rows, or folded
/// when it is quiet; then, last, one line counting its jobs. The job under
/// the cursor, `lead` (its index), keeps the rows (`led`). None when there are no
/// jobs (one shape, empty). The blank line above the section is the table's to give.
#[must_use]
pub fn shapes(board: &Board, lead: Option<usize>, named: bool) -> Vec<Vec<Piece<'_>>> {
    let jobs = &board.jobs;
    if jobs.is_empty() {
        return vec![Vec::new()];
    }
    let label = Piece::JobsLabel(title(jobs), lead.is_none());
    if let Some(lead) = lead {
        return led(jobs, lead, named, &label);
    }
    let first = if quiet(jobs) { vec![label, Piece::JobsFolded(jobs)] } else { std::iter::once(label).chain(rows(jobs, 0..jobs.len(), None, named)).collect() };
    vec![first, vec![Piece::JobsCounted(jobs, title(jobs))]]
}

/// The section with the cursor on job `lead`, most room first: every row,
/// then fewer, those furthest from the lead's given up first, then the
/// lead's alone, then without the label, so the cursor's row stays on the
/// screen however short it is.
fn led<'a>(jobs: &'a [Job], lead: usize, named: bool, label: &Piece<'a>) -> Vec<Vec<Piece<'a>>> {
    let window = |keep: usize| {
        let start = lead.saturating_sub(keep / 2).min(jobs.len() - keep);
        std::iter::once(label.clone()).chain(rows(jobs, start..start + keep, Some(lead), named)).collect()
    };
    (1..=jobs.len()).rev().map(window).chain([rows(jobs, lead..=lead, Some(lead), named)]).collect()
}

/// The rows of the jobs at `at`, the lead's between the block's edges.
fn rows(jobs: &[Job], at: impl std::ops::RangeBounds<usize>, lead: Option<usize>, named: bool) -> Vec<Piece<'_>> {
    jobs.iter().enumerate().filter(|(i, _)| at.contains(i)).flat_map(|(i, job)| {
        let leads = lead == Some(i);
        let row = Piece::Job(job, name(job, named), leads);
        if leads { vec![Piece::Edge(true), row, Piece::Edge(false)] } else { vec![row] }
    }).collect()
}

/// A job's name as its row shows it: after its project's when the board holds more than one.
#[must_use]
pub fn name(job: &Job, named: bool) -> String {
    match job.project.as_deref() {
        Some(project) if named => format!("{} · {}", project_name(project), job.name),
        _ => job.name.clone(),
    }
}

/// Whether a job needs you: its latest run failed, ran out of time, or
/// stopped without a result, and the user has not hidden it.
#[must_use]
pub fn needs_you(job: &Job) -> bool {
    job.hidden.is_none() && matches!(job.status, JobStatus::Failed | JobStatus::Timeout | JobStatus::Lost)
}

/// Whether nothing in the section needs you or runs, and it shows no hidden
/// job: those the user asked to see, each on its row.
#[must_use]
pub fn quiet(jobs: &[Job]) -> bool {
    jobs.iter().all(|job| job.hidden.is_none() && matches!(job.status, JobStatus::Passed | JobStatus::Due))
}

/// The index of the job under the cursor: past the last run.
#[must_use]
pub fn lead(board: &Board) -> Option<usize> {
    let index = board.view.cursor?.checked_sub(board.runs.len())?;
    (index < board.jobs.len()).then_some(index)
}

/// Whether more than one project has a run or a job on the board.
#[must_use]
pub fn many_projects(board: &Board) -> bool {
    let projects = board.runs.iter().map(|run| run.commit.project.as_deref()).chain(board.jobs.iter().map(|job| job.project.as_deref()));
    let mut seen: Vec<Option<&str>> = projects.collect();
    seen.sort_unstable();
    seen.dedup();
    seen.len() > 1
}
