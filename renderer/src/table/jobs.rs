//! The daily and weekly jobs below the table (design.md, Daily and weekly
//! jobs): a section of their own under the last project, one row a job, the
//! row under the cursor in the block. A quiet section, where nothing needs
//! you or runs, folds into one line; on a short screen the section gives up
//! its lines before any branch does, keeping one that counts the jobs.

use super::stack::Piece;
use crate::format::project_name;
use crate::model::{Board, Job};

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
/// the cursor, `lead` (its index), keeps the rows. None when there are no
/// jobs (one shape, empty). The blank line above the section is the table's to give.
#[must_use]
pub fn shapes(board: &Board, lead: Option<usize>, named: bool) -> Vec<Vec<Piece<'_>>> {
    let jobs = &board.jobs;
    if jobs.is_empty() {
        return vec![Vec::new()];
    }
    let label = [Piece::JobsLabel(title(jobs))];
    if lead.is_some() {
        return vec![label.into_iter().chain(rows(jobs, lead, named)).collect()];
    }
    let first = if quiet(jobs) { label.into_iter().chain([Piece::JobsFolded(jobs)]).collect() } else { label.into_iter().chain(rows(jobs, None, named)).collect() };
    vec![first, vec![Piece::JobsCounted(jobs, title(jobs))]]
}

/// Each job's row, the lead's between the block's edges.
fn rows(jobs: &[Job], lead: Option<usize>, named: bool) -> Vec<Piece<'_>> {
    jobs.iter().enumerate().flat_map(|(i, job)| {
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

/// Whether a job needs you: its latest run failed, ran out of time, or stopped without a result.
#[must_use]
pub fn needs_you(job: &Job) -> bool {
    matches!(job.status.as_str(), "failed" | "timeout" | "lost")
}

/// Whether nothing in the section needs you or runs.
#[must_use]
pub fn quiet(jobs: &[Job]) -> bool {
    jobs.iter().all(|job| matches!(job.status.as_str(), "passed" | "due"))
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
