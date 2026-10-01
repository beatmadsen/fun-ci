//! Which label the jobs' section takes and which job the cursor is on
//! (design.md, Daily and weekly jobs; acceptance-tests.md, AT-13.18).

use fun_ci_renderer::model::{Board, Job};
use fun_ci_renderer::table::jobs::{lead, title};
use serde_json::{Value, json};

fn job(name: &str, cadence: &str) -> Value {
    json!({"name": name, "cadence": cadence, "status": "passed"})
}

fn jobs(cadences: &[&str]) -> Vec<Job> {
    cadences.iter().map(|cadence| serde_json::from_value(job("soak", cadence)).unwrap()).collect()
}

fn board(jobs: usize, cursor: usize) -> Board {
    let jobs: Vec<Value> = (0..jobs).map(|i| job(&format!("job{i}"), "daily")).collect();
    serde_json::from_value(json!({"t": "board", "now": 0, "cursor": cursor, "runs": [], "jobs": jobs})).unwrap()
}

#[test]
fn a_section_of_daily_jobs_alone_is_labelled_daily() {
    assert_eq!(title(&jobs(&["daily", "daily"])), "daily");
}

#[test]
fn a_section_of_both_cadences_is_labelled_with_both() {
    assert_eq!(title(&jobs(&["daily", "weekly"])), "daily & weekly");
}

#[test]
fn the_cursor_on_the_last_job_leads_it() {
    assert_eq!(lead(&board(2, 1)), Some(1));
}

#[test]
fn the_cursor_past_the_last_job_leads_none() {
    assert_eq!(lead(&board(2, 2)), None);
}
