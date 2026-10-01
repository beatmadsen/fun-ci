//! The daily and weekly jobs below the table (design.md, Daily and weekly
//! jobs; acceptance-tests.md, AT-13.18, AT-13.19): a section of their own
//! under the last project, each row a job's name, how often it runs, its
//! mark, what happened and when; the legend's lines end above it; the cursor
//! takes the block onto a job; a quiet section folds to one line, and a
//! short screen keeps one line of it before folding any branch.

use crate::support::quiet::{NOW, failed, in_the_block, passed, said, screen_with, unstriped};
use fun_ci_renderer::grid::{Colour, Grid};
use fun_ci_renderer::table::night::{FAILED, RUNNING};
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
fn a_line_of_jobs_where_one_runs_has_a_stripe_in_the_running_colour() {
    let runs = [failed(3, "feat", "/src/app"), passed(2, "main", "/src/app"), passed(1, "dev", "/src/app")];
    let jobs = [job("a", "daily", "passed"), job("b", "daily", "passed"), job("c", "daily", "passed"), job("soak", "weekly", "running")];
    let grid = shown(&runs, &jobs, None, (120, 30));
    let row = row_index(&grid, "daily & weekly: ");

    let stripe = grid.cells[row].iter().find(|cell| cell.text == "▌").unwrap();

    assert_eq!(stripe.fg, Colour::Rgb(RUNNING[0], RUNNING[1], RUNNING[2]));
}

// Two branches and two jobs, one failed, take 29 lines with the section's
// rows and the blank line above them; 30 with the cursor on the last
// branch, whose block ends the table with no blank line of its own.
fn two_branches_and_two_jobs(rows: u16) -> Grid {
    two_branches_and_two_jobs_at(rows, None)
}

fn two_branches_and_two_jobs_at(rows: u16, cursor: Option<usize>) -> Grid {
    let runs = [failed(2, "feat", "/src/app"), passed(1, "main", "/src/app")];
    shown(&runs, &[job("soak", "daily", "failed"), job("mutation", "daily", "passed")], cursor, (120, rows))
}

#[test]
fn under_the_block_a_screen_with_room_for_the_jobs_rows_and_a_blank_above_them_shows_the_rows() {
    let lines = said(&two_branches_and_two_jobs_at(30, Some(1)));

    assert_eq!(lines[lines.len() - 3..lines.len() - 1], ["soak".to_string(), "mutation".to_string()]);
}

#[test]
fn under_the_block_a_screen_a_line_short_of_the_jobs_rows_counts_the_jobs_on_one_line() {
    let lines = said(&two_branches_and_two_jobs_at(29, Some(1)));

    assert_eq!(lines[lines.len() - 2], "daily: 1 failed, 1 passed");
}

// The table is fitted to what the section leaves it, its blank line
// included, so a table that has a line to spare says its legend on it.
#[test]
fn under_the_block_a_screen_with_a_line_to_spare_after_the_jobs_says_the_legend_on_it() {
    let lines = said(&two_branches_and_two_jobs_at(22, Some(1)));

    assert_eq!(lines[2..4], ["daily: 1 failed, 1 passed".to_string(), "marks, left to right: lint · build · fast suite · slow suite".to_string()]);
}

// Jobs come after the branches: their last line goes before the table has
// to page a branch, the cursor's included, off the screen.
#[test]
fn a_screen_too_short_for_the_branches_and_a_line_of_jobs_keeps_the_branches() {
    let lines = said(&two_branches_and_two_jobs_at(20, Some(1)));

    assert_eq!(lines[..2], ["feat".to_string(), "main".to_string()]);
}

#[test]
fn a_screen_too_short_for_the_branches_and_a_line_of_jobs_shows_no_jobs() {
    let lines = said(&two_branches_and_two_jobs_at(20, Some(1)));

    assert!(!lines.iter().any(|line| line.starts_with("daily")), "{lines:?}");
}

// Nor do they cost a passed branch its row, left out and counted beside the keys.
#[test]
fn a_screen_too_short_for_both_branches_and_a_line_of_jobs_leaves_no_branch_out() {
    let lines = said(&two_branches_and_two_jobs(21));

    assert_eq!(lines[..2], ["feat".to_string(), "main".to_string()]);
}

// Unless the cursor is on a job: its rows stay, whatever that costs the branches.
#[test]
fn a_short_screen_keeps_the_rows_of_the_jobs_the_cursor_is_on() {
    let lines = said(&two_branches_and_two_jobs_at(21, Some(2)));

    assert!(lines.contains(&"soak".to_string()), "{lines:?}");
}

// Two projects, one of them running, and their jobs on a 60-column screen,
// where the footer's three keys leave little room beside them.
fn narrow(cursor: Option<usize>) -> Grid {
    let runs = [failed(2, "feat", "/src/app"), passed(1, "main", "/src/tool")];
    let mut drift = job("drift", "weekly", "failed");
    drift["project"] = json!("/src/tool");
    shown(&runs, &[job("mutation", "daily", "running"), drift], cursor, (60, 30))
}

#[test]
fn on_a_narrow_screen_a_job_too_long_to_name_with_its_project_is_named_alone() {
    let lines = said(&narrow(Some(3)));

    assert!(lines.contains(&"mutation".to_string()), "{lines:?}");
}

#[test]
fn on_a_narrow_screen_the_command_for_a_failed_job_is_shown_whole() {
    let grid = narrow(Some(3));

    assert!(grid.text().contains("fun-ci why --job drift"), "{}", grid.text());
}

#[test]
fn one_blank_line_parts_the_jobs_from_the_block_s_lower_edge() {
    let grid = two_branches_and_two_jobs_at(30, Some(1));
    let label = row_index(&grid, "D A I L Y");
    let text = grid.text();
    let lines: Vec<&str> = text.lines().collect();

    assert_eq!((lines[label - 1].trim(), lines[label - 2].trim().starts_with('▝')), ("", true));
}

#[test]
fn a_screen_with_room_for_the_jobs_rows_and_the_blank_above_them_shows_the_rows() {
    let lines = said(&two_branches_and_two_jobs(29));

    assert_eq!(lines[lines.len() - 3..lines.len() - 1], ["soak".to_string(), "mutation".to_string()]);
}

#[test]
fn a_screen_a_line_short_of_the_jobs_rows_counts_the_jobs_on_one_line() {
    let lines = said(&two_branches_and_two_jobs(28));

    assert_eq!(lines[lines.len() - 2], "daily: 1 failed, 1 passed");
}

#[test]
fn one_blank_line_parts_the_jobs_from_the_branches() {
    let grid = two_branches_and_two_jobs(29);
    let label = row_index(&grid, "D A I L Y");
    let text = grid.text();
    let lines: Vec<&str> = text.lines().collect();

    assert_eq!((lines[label - 1].trim(), unstriped(lines[label - 2]).starts_with("main")), ("", true));
}

#[test]
fn with_more_than_one_project_a_job_names_its_project() {
    let runs = [failed(2, "feat", "/src/app"), passed(1, "main", "/src/tool")];

    let grid = shown(&runs, &needing(), None, (120, 40));

    assert!(line_of(&grid, "app · soak").contains("weekly"), "{}", grid.text());
}

// At 65 columns the name column is exactly as wide as `app · mutation`, the
// narrowest screen where it is (at 64 the job goes by `mutation` alone).
#[test]
fn a_job_whose_name_with_its_project_just_fits_keeps_its_project() {
    let runs = [failed(2, "feat", "/src/app"), passed(1, "main", "/src/tool")];
    let jobs = [job("soak", "weekly", "failed"), job("mutation", "daily", "passed")];

    let lines = said(&shown(&runs, &jobs, Some(2), (65, 40)));

    assert!(lines.contains(&"app · mutation".to_string()), "{lines:?}");
}

// A failed job under the cursor, with a run going so the footer has all
// three keys: its command fits beside them from 76 columns.
fn failed_job_under_the_cursor(cols: u16) -> String {
    let jobs = [job("soak", "weekly", "failed"), job("mutation", "daily", "running")];
    shown(&[failed(2, "feat", "/src/app")], &jobs, Some(1), (cols, 40)).text()
}

#[test]
fn the_command_for_a_failed_job_goes_beside_the_keys_where_it_fits() {
    assert!(failed_job_under_the_cursor(76).lines().last().unwrap().contains("fun-ci why --job soak"));
}

#[test]
fn the_command_for_a_failed_job_goes_above_the_footer_a_column_short_of_that() {
    let text = failed_job_under_the_cursor(75);
    let lines: Vec<&str> = text.lines().collect();

    assert_eq!(lines.iter().position(|line| line.contains("fun-ci why --job soak")), Some(lines.len() - 3), "{text}");
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
fn the_cursor_on_a_job_that_needs_you_shows_the_command_that_says_why() {
    let grid = shown(&[passed(1, "main", "/src/app")], &needing(), Some(1), (120, 40));

    assert!(grid.text().lines().last().unwrap().trim_end().ends_with("fun-ci why --job soak"), "{}", grid.text());
}

#[test]
fn the_cursor_on_a_passed_job_shows_no_command() {
    let grid = shown(&[passed(1, "main", "/src/app")], &needing(), Some(2), (120, 40));

    assert!(!grid.text().contains("fun-ci why"), "{}", grid.text());
}

#[test]
fn on_sixty_columns_a_job_says_what_happened_briefly() {
    let grid = shown(&[failed(1, "feat", "/src/app")], &needing(), None, (60, 30));

    assert!(line_of(&grid, "soak").contains("failed · 3h12m"), "{}", grid.text());
}

#[test]
fn a_running_job_offers_the_cancel_key() {
    let jobs = [json!({"project": "/src/app", "name": "soak", "cadence": "weekly", "status": "running", "run_id": 9, "sha": SHA,
                       "branch": "main", "started_at": NOW - 600, "updated_at": NOW - 600})];

    assert!(shown(&[passed(1, "main", "/src/app")], &jobs, None, (120, 40)).text().contains(" c  cancel"));
}
