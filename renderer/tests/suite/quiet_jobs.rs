//! The daily and weekly jobs below the table (design.md, Daily and weekly
//! jobs; acceptance-tests.md, AT-13.18, AT-13.19): a section of their own
//! under the last project, each row a job's name, how often it runs, its
//! mark, what happened and when; the legend's lines end above it; the cursor
//! takes the block onto a job; a quiet section folds to one line, and a
//! short screen keeps one line of it before folding any branch.

use crate::support::quiet::{NOW, failed, in_the_block, passed, said, screen_with, unstriped};
use fun_ci_renderer::grid::{Colour, Grid};
use fun_ci_renderer::table::night::FAILED;
use serde_json::{Value, json};

const SHA: &str = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4";

fn job(name: &str, cadence: &str, status: &str) -> Value {
    json!({"project": "/src/app", "name": name, "cadence": cadence, "status": status, "run_id": 9, "sha": SHA,
           "branch": "main", "started_at": NOW - 20_000, "updated_at": NOW - 8_480, "due_at": NOW + 50_400})
}

fn board(runs: &[Value], jobs: &[Value], cursor: Option<usize>) -> Value {
    json!({"t": "board", "now": NOW, "cursor": cursor, "runs": runs, "jobs": jobs})
}

fn shown(runs: &[Value], jobs: &[Value], cursor: Option<usize>, size: (u16, u16)) -> Grid {
    screen_with(&board(runs, jobs, cursor), size)
}

/// The screen's line that starts with `name`, after any stripe.
fn line_of(grid: &Grid, name: &str) -> String {
    let text = grid.text();
    text.lines().find(|line| unstriped(line).starts_with(name)).unwrap_or_else(|| panic!("no {name:?} in\n{text}")).to_string()
}

fn row_index(grid: &Grid, name: &str) -> usize {
    grid.text().lines().position(|line| unstriped(line).starts_with(name)).unwrap()
}

fn needing() -> Vec<Value> {
    vec![job("soak", "weekly", "failed"), job("mutation", "daily", "passed")]
}

#[test]
fn the_jobs_sit_under_their_own_label_below_the_last_project() {
    let grid = shown(&[failed(2, "feat", "/src/app"), passed(1, "main", "/src/app")], &needing(), None, (120, 40));

    assert!(row_index(&grid, "D A I L Y   &   W E E K L Y") > row_index(&grid, "main"), "{}", grid.text());
}

#[test]
fn a_section_of_weekly_jobs_alone_is_labelled_weekly() {
    let grid = shown(&[failed(1, "feat", "/src/app")], &[job("soak", "weekly", "failed")], None, (120, 40));

    assert_eq!(unstriped(&line_of(&grid, "W E E K L Y")).split("  ").next(), Some("W E E K L Y"));
}

#[test]
fn a_job_s_row_reads_its_name_how_often_its_mark_and_what_happened() {
    let grid = shown(&[failed(1, "feat", "/src/app")], &needing(), None, (120, 40));

    let words: Vec<String> = unstriped(&line_of(&grid, "soak")).split("  ").map(str::trim).filter(|w| !w.is_empty()).map(str::to_string).collect();

    assert_eq!(words[..4], ["soak", "weekly ◆", "failed after 3h12m on main 9e0b1d4 · due in 14h", "2h"]);
}

#[test]
fn a_failed_job_has_a_stripe_in_the_failed_colour() {
    let grid = shown(&[failed(1, "feat", "/src/app")], &needing(), None, (120, 40));
    let row = row_index(&grid, "soak");

    let stripe = grid.cells[row].iter().find(|cell| cell.text == "▌").unwrap();

    assert_eq!(stripe.fg, Colour::Rgb(FAILED[0], FAILED[1], FAILED[2]));
}

#[test]
fn a_lost_job_has_a_stripe_in_the_failed_colour() {
    let grid = shown(&[failed(1, "feat", "/src/app")], &[job("soak", "weekly", "lost")], None, (120, 40));
    let row = row_index(&grid, "soak");

    let stripe = grid.cells[row].iter().find(|cell| cell.text == "▌").unwrap();

    assert_eq!(stripe.fg, Colour::Rgb(FAILED[0], FAILED[1], FAILED[2]));
}

#[test]
fn the_legend_s_lines_end_above_the_jobs() {
    let grid = shown(&[failed(2, "feat", "/src/app"), passed(1, "main", "/src/app")], &needing(), None, (120, 40));
    let label = row_index(&grid, "D A I L Y");

    assert!(grid.text().lines().skip(label - 1).all(|line| !line.contains('│')), "{}", grid.text());
}

#[test]
fn the_cursor_on_a_job_takes_the_block() {
    let grid = shown(&[failed(1, "feat", "/src/app")], &needing(), Some(2), (120, 40));

    assert_eq!(in_the_block(&grid), ["mutation"]);
}

#[test]
fn a_quiet_section_folds_into_one_line_saying_how_many_passed_and_what_is_due_next() {
    let jobs = [job("soak", "weekly", "passed"), json!({"project": "/src/app", "name": "mutation", "cadence": "daily", "status": "passed",
                                                         "run_id": 3, "sha": SHA, "branch": "main", "started_at": NOW - 80_000,
                                                         "updated_at": NOW - 79_000, "due_at": NOW + 21_600})];

    let lines = said(&shown(&[passed(1, "main", "/src/app")], &jobs, None, (120, 40)));

    assert!(lines.contains(&"✓ 2 passed · mutation due in 6h".to_string()), "{lines:?}");
}

#[test]
fn a_short_screen_keeps_one_line_of_jobs_before_folding_a_branch() {
    let runs = [failed(3, "feat", "/src/app"), passed(2, "main", "/src/app"), passed(1, "dev", "/src/app")];
    let jobs = [job("soak", "weekly", "failed"), job("a", "daily", "passed"), job("b", "daily", "passed"), job("c", "daily", "passed")];

    let lines = said(&shown(&runs, &jobs, None, (120, 30)));

    assert_eq!(lines[lines.len() - 3..lines.len() - 1], ["dev".to_string(), "daily & weekly: 1 failed, 3 passed".to_string()]);
}

#[test]
fn with_more_than_one_project_a_job_names_its_project() {
    let runs = [failed(2, "feat", "/src/app"), passed(1, "main", "/src/tool")];

    let grid = shown(&runs, &needing(), None, (120, 40));

    assert!(line_of(&grid, "app · soak").contains("weekly"), "{}", grid.text());
}

#[test]
fn confirming_a_cancel_on_a_job_names_the_job_and_its_commit() {
    let jobs = [json!({"project": "/src/app", "name": "soak", "cadence": "weekly", "status": "running", "run_id": 9, "sha": SHA,
                       "branch": "main", "started_at": NOW - 600, "updated_at": NOW - 600})];
    let mut confirming = board(&[passed(1, "main", "/src/app")], &jobs, Some(1));
    confirming["confirming"] = json!(true);

    assert!(screen_with(&confirming, (120, 40)).text().contains("Cancel soak (9e0b1d4)?"));
}

#[test]
fn a_running_job_offers_the_cancel_key() {
    let jobs = [json!({"project": "/src/app", "name": "soak", "cadence": "weekly", "status": "running", "run_id": 9, "sha": SHA,
                       "branch": "main", "started_at": NOW - 600, "updated_at": NOW - 600})];

    assert!(shown(&[passed(1, "main", "/src/app")], &jobs, None, (120, 40)).text().contains(" c  cancel"));
}
