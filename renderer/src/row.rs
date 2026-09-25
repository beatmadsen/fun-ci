//! One run as one line of the board, as the 1.x `RowFormatter` drew it.

use crate::ansi::{BOLD_CYAN, BOLD_GREEN, BOLD_RED, BOLD_YELLOW, CYAN, DIM, GREEN, RESET, paint};
use crate::format::{age, duration, finished_word, project_colour, project_name, seconds_since, short_sha, stage_label};
use crate::model::{Run, Stage};

const IDLE_SPINNER: char = '\u{2800}';

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Progress {
    spinner: char,
    elapsed: Option<i64>,
}

/// The run's line. `now_ms` is the frame's clock; `spinner` is the current
/// spinner frame, shown only while the run is running.
#[must_use]
pub fn format_run(run: &Run, now_ms: i64, spinner: char) -> String {
    let head = format!("  {}  {}{}", short_sha(&run.commit.sha), run.commit.branch, project(run));
    let age = age(run.state.updated_at, now_ms);
    match run.status() {
        "pending" => paint(DIM, &format!("{head}  Scheduled...  {age}")),
        "cancelled" => paint(DIM, &format!("{head}  {}  CANCELLED  {age}", cancelled_stages(run))),
        status => format!("{head}  {}  {}  {}", stages(run, now_ms, spinner), status_text(status), paint(DIM, &age)),
    }
}

fn project(run: &Run) -> String {
    let Some(path) = &run.commit.project else {
        return String::new();
    };
    let name = project_name(path);
    format!("  \u{1b}[{}m{name}{RESET}", project_colour(&name))
}

fn cancelled_stages(run: &Run) -> String {
    let stage = |s: &Stage| format!("{} {}", label(s), s.duration_ms.map_or("--".to_string(), duration));
    run.stages.iter().map(stage).collect::<Vec<_>>().join("  ")
}

fn stages(run: &Run, now_ms: i64, spinner: char) -> String {
    let progress = progress(run, now_ms, spinner);
    run.stages.iter().map(|s| stage(s, progress)).collect::<Vec<_>>().join("  ")
}

fn progress(run: &Run, now_ms: i64, spinner: char) -> Progress {
    if run.status() != "running" {
        return Progress { spinner: IDLE_SPINNER, elapsed: None };
    }
    let active = run.stages.iter().find(|s| s.status == "running");
    let elapsed = active.and_then(|s| s.started_at).map(|started| seconds_since(started, now_ms));
    Progress { spinner, elapsed }
}

fn stage(stage: &Stage, progress: Progress) -> String {
    let name = label(stage);
    if stage.status == "running" {
        return paint(CYAN, &format!("{name} {} {}", progress.spinner, running_time(progress)));
    }
    finished(stage).unwrap_or_else(|| paint(DIM, &format!("{name} --")))
}

fn finished(stage: &Stage) -> Option<String> {
    let word = finished_word(&stage.status)?;
    let took = stage.duration_ms.map(duration).unwrap_or_default();
    Some(paint(finished_colour(&stage.status), &format!("{}{word} {took}", label(stage))))
}

fn finished_colour(status: &str) -> &'static str {
    match status {
        "passed" => GREEN,
        "failed" => BOLD_RED,
        _ => BOLD_YELLOW,
    }
}

fn running_time(progress: Progress) -> String {
    progress.elapsed.map_or("--".to_string(), |s| format!("{s}s"))
}

fn status_text(status: &str) -> String {
    match status {
        "passed" => paint(BOLD_GREEN, "PASSED"),
        "failed" => paint(BOLD_RED, "FAILED"),
        "timeout" => paint(BOLD_YELLOW, "TIMED OUT"),
        "running" => paint(BOLD_CYAN, "RUNNING"),
        _ => paint(DIM, ""),
    }
}

fn label(stage: &Stage) -> &'static str {
    stage_label(&stage.stage).unwrap_or_default()
}
