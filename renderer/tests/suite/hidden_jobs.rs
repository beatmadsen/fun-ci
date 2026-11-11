//! Hidden jobs on the screen (design.md, The console; acceptance-tests.md,
//! AT-13.29 to AT-13.31): the footer asks how to hide a job and says how
//! many are hidden; once shown, a hidden job's row is pale and unstriped,
//! says how it was hidden, and neither needs you nor counts as failed.

use crate::support::quiet::{NOW, failed, paper, passed, said, screen_with, unstriped};
use fun_ci_renderer::grid::{Colour, Grid};
use fun_ci_renderer::table::night::{INDIGO, QUIET};
use serde_json::{Value, json};

fn job(name: &str, status: &str, hidden: Option<&str>) -> Value {
    json!({"project": "/src/app", "name": name, "cadence": "daily", "status": status, "run_id": 9, "sha": "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4",
           "branch": "main", "started_at": NOW - 20_000, "updated_at": NOW - 8_480, "due_at": NOW + 50_400, "hidden": hidden})
}

/// A passed branch and `jobs` on a screen of `size`, with `more` of a board's fields.
fn shown(jobs: &[Value], more: &Value, size: (u16, u16)) -> Grid {
    let mut board = json!({"t": "board", "now": NOW, "cursor": null, "runs": [passed(1, "main", "/src/app")], "jobs": jobs});
    board.as_object_mut().unwrap().extend(more.as_object().unwrap().clone());
    screen_with(&board, size)
}

fn line_of(grid: &Grid, name: &str) -> String {
    let text = grid.text();
    text.lines().find(|line| unstriped(line).starts_with(name)).unwrap_or_else(|| panic!("no {name:?} in\n{text}")).to_string()
}

fn footer(grid: &Grid) -> String {
    grid.text().lines().last().unwrap().trim_end().to_string()
}

fn snoozed_and_passed() -> Vec<Value> {
    vec![job("mutation", "passed", None), job("soak", "failed", Some("snoozed"))]
}

#[test]
fn the_footer_asks_how_to_hide_the_job_under_the_cursor() {
    let grid = shown(&[job("soak", "failed", None)], &json!({"cursor": 1, "hiding": true}), (120, 40));

    assert!(footer(&grid).contains("Hide soak?   s  snooze until its next run"), "{}", grid.text());
}

// A name too long for the screen is cut, so the keys that answer are whole.
#[test]
fn on_a_narrow_screen_the_question_gives_way_to_the_keys_that_answer_it() {
    let long = job("a-job-with-quite-a-long-name-to-ask-about", "failed", None);
    let grid = shown(&[long], &json!({"cursor": 1, "hiding": true}), (60, 30));

    assert!(footer(&grid).ends_with("…   s  snooze     i  ignore     n  no"), "{}", grid.text());
}

#[test]
fn the_footer_says_jobs_are_hidden_when_none_is_on_the_board() {
    let grid = shown(&[], &json!({"hidden_rows": 2}), (120, 40));

    assert!(footer(&grid).ends_with("a shows 2 hidden rows"), "{}", grid.text());
}

#[test]
fn the_footer_says_what_a_short_screen_left_out_before_the_hidden_jobs() {
    let runs = [failed(3, "feat", "/src/app"), passed(2, "main", "/src/app"), passed(1, "old", "/src/app")];
    let board = json!({"t": "board", "now": NOW, "cursor": null, "runs": runs, "hidden_rows": 1});

    assert!(footer(&screen_with(&board, (120, 19))).ends_with("2 passed not shown · a shows 1 hidden row"), "{}", screen_with(&board, (120, 19)).text());
}

#[test]
fn a_hidden_job_s_row_says_how_it_was_hidden() {
    let grid = shown(&snoozed_and_passed(), &json!({"hidden_rows": 1}), (120, 40));

    assert!(line_of(&grid, "soak").contains("snoozed until its next run"), "{}", grid.text());
}

#[test]
fn a_hidden_job_that_failed_has_no_stripe() {
    let grid = shown(&snoozed_and_passed(), &json!({"hidden_rows": 1}), (120, 40));

    assert!(!line_of(&grid, "soak").trim_start().starts_with('▌'), "{}", grid.text());
}

// The user asked to see them: a section that would fold shows its rows.
#[test]
fn hidden_jobs_shown_keep_their_rows_in_a_quiet_section() {
    let jobs = [job("mutation", "passed", None), job("soak", "passed", Some("ignored"))];
    let lines = said(&shown(&jobs, &json!({"hidden_rows": 1}), (120, 40)));

    assert!(lines.contains(&"soak".to_string()), "{lines:?}");
}

#[test]
fn a_hidden_job_that_failed_under_the_cursor_leaves_the_block_calm() {
    let grid = shown(&snoozed_and_passed(), &json!({"hidden_rows": 1, "cursor": 2}), (120, 40));

    assert_eq!(paper(&grid), Colour::Rgb(INDIGO[0], INDIGO[1], INDIGO[2]));
}

#[test]
fn a_hidden_job_that_failed_under_the_cursor_shows_no_command() {
    let grid = shown(&snoozed_and_passed(), &json!({"hidden_rows": 1, "cursor": 2}), (120, 40));

    assert!(!grid.text().contains("fun-ci why"), "{}", grid.text());
}

#[test]
fn a_hidden_job_s_name_is_as_pale_as_a_passed_job_s() {
    let grid = shown(&snoozed_and_passed(), &json!({"hidden_rows": 1}), (120, 40));

    assert_eq!(name_colour(&grid, "soak"), name_colour(&grid, "mutation"));
}

// Under the cursor too, or its mark alone would say it needs you.
#[test]
fn a_hidden_job_that_failed_under_the_cursor_has_a_mark_as_quiet_as_its_words() {
    let grid = shown(&snoozed_and_passed(), &json!({"hidden_rows": 1, "cursor": 2}), (120, 40));

    assert_eq!(mark_colour(&grid, "soak"), Colour::Rgb(QUIET[0], QUIET[1], QUIET[2]));
}

/// The colour of the mark on the row that starts with `name`.
fn mark_colour(grid: &Grid, name: &str) -> Colour {
    let text = grid.text();
    let (row, line) = text.lines().enumerate().find(|(_, line)| unstriped(line).starts_with(name)).unwrap();
    grid.cells[row][line.chars().position(|c| c == '◆').unwrap()].fg
}

/// The colour of the first letter of the row that starts with `name`.
fn name_colour(grid: &Grid, name: &str) -> Colour {
    let text = grid.text();
    let (row, line) = text.lines().enumerate().find(|(_, line)| unstriped(line).starts_with(name)).unwrap();
    grid.cells[row][line.chars().position(|c| !c.is_whitespace() && c != '▌').unwrap()].fg
}

// On a screen too short for the rows, the section's one line counts the hidden apart.
#[test]
fn a_short_screen_counts_a_hidden_job_as_hidden_not_as_failed() {
    let lines = said(&shown(&snoozed_and_passed(), &json!({"hidden_rows": 1}), (120, 24)));

    assert!(lines.contains(&"daily: 1 passed, 1 hidden".to_string()), "{lines:?}");
}

#[test]
fn a_short_screen_gives_its_line_of_jobs_no_stripe_for_a_hidden_job_that_runs() {
    let jobs = [job("mutation", "passed", None), job("soak", "running", Some("ignored"))];
    let grid = shown(&jobs, &json!({"hidden_rows": 1}), (120, 24));

    assert!(!line_of(&grid, "daily: 1 passed, 1 hidden").trim_start().starts_with('▌'), "{}", grid.text());
}

// Not in the colour of what happened: it is out of view for the user.
#[test]
fn a_hidden_job_says_how_it_was_hidden_as_quietly_as_a_due_job_says_it_is_due() {
    let grid = shown(&snoozed_and_passed(), &json!({"hidden_rows": 1}), (120, 40));
    let text = grid.text();
    let (row, line) = text.lines().enumerate().find(|(_, line)| line.contains("snoozed until")).unwrap();
    let at = line.chars().take(line.find("snoozed until").unwrap()).count();

    assert_eq!(grid.cells[row][at].fg, Colour::Rgb(QUIET[0], QUIET[1], QUIET[2]));
}

// The footer asks one thing at a time.
#[test]
fn the_footer_shows_no_command_while_it_asks_how_to_hide_a_failed_job() {
    let grid = shown(&[job("soak", "failed", None)], &json!({"cursor": 1, "hiding": true}), (120, 40));

    assert!(!grid.text().contains("fun-ci why"), "{}", grid.text());
}

#[test]
fn the_footer_says_jobs_are_hidden_beside_the_command_for_a_failed_job() {
    let grid = shown(&[job("soak", "failed", None)], &json!({"cursor": 1, "hidden_rows": 1}), (160, 40));

    assert!(footer(&grid).ends_with("fun-ci why --job soak · a shows 1 hidden row"), "{}", grid.text());
}

// The command can't be cut and the count can't be left out, so the command takes the line above.
#[test]
fn the_command_for_a_failed_job_goes_above_the_footer_when_the_hidden_jobs_leave_it_no_room() {
    let grid = shown(&[job("soak", "failed", None)], &json!({"cursor": 1, "hidden_rows": 1}), (80, 40));
    let text = grid.text();
    let above = text.lines().any(|line| line.trim() == "fun-ci why --job soak");

    assert_eq!((above, footer(&grid).ends_with("a shows 1 hidden row")), (true, true), "{text}");
}

#[test]
fn a_narrow_footer_says_how_many_jobs_are_hidden_in_fewer_words_rather_than_cut() {
    let grid = shown(&[job("mutation", "passed", None)], &json!({"cursor": 1, "hidden_rows": 1}), (60, 30));

    assert!(footer(&grid).ends_with(" 1 hidden"), "{}", grid.text());
}

#[test]
fn a_narrow_footer_says_what_a_short_screen_left_out_in_fewer_words_rather_than_cut() {
    let runs = [failed(3, "feat", "/src/app"), passed(2, "main", "/src/app"), passed(1, "old", "/src/app")];
    let board = json!({"t": "board", "now": NOW, "cursor": null, "runs": runs, "hidden_rows": 1});
    let grid = screen_with(&board, (60, 19));

    assert!(!footer(&grid).contains('…'), "{}", grid.text());
}

#[test]
fn the_question_says_how_long_a_job_stays_hidden_where_there_is_room() {
    let grid = shown(&[job("soak", "failed", None)], &json!({"cursor": 1, "hiding": true}), (120, 40));

    assert!(footer(&grid).contains("i  ignore until shown again     n  no"), "{}", grid.text());
}
