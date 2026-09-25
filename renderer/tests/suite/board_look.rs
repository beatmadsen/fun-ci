//! How the board shows the cursor, the footer and the spinner, as the 1.x
//! console's Cucumber features specified them.

use fun_ci_renderer::grid::Grid;
use serde_json::{Value, json};

use crate::support::boards::{board, frames, last_screen, run, then_ticks};
use fun_ci_renderer::headless::emulate;

fn two_runs() -> Vec<Value> {
    vec![run(1, "passed", &[("lint", "passed")]), run(2, "passed", &[("lint", "passed")])]
}

fn with_cursor(runs: &[Value], cursor: usize) -> String {
    let mut drawn: Value = serde_json::from_str(&board(runs)).unwrap();
    drawn["cursor"] = json!(cursor);
    drawn.to_string()
}

fn screen_rows(screen: &Grid) -> Vec<String> {
    screen.text().lines().map(str::to_string).collect()
}

/// The screen row that shows `text`, and the column it starts at.
fn find(screen: &Grid, text: &str) -> (usize, usize) {
    let rows = screen_rows(screen);
    let row = rows.iter().position(|line| line.contains(text)).unwrap_or_else(|| panic!("no {text:?} on screen"));
    (row, rows[row][..rows[row].find(text).unwrap()].chars().count())
}

#[test]
fn no_row_is_marked_while_no_run_is_under_the_cursor() {
    let screen = last_screen(&then_ticks(&[board(&two_runs())], 1));
    assert!(!screen.text().contains("> "));
}

#[test]
fn the_row_under_the_cursor_is_marked() {
    let screen = last_screen(&then_ticks(&[with_cursor(&two_runs(), 1)], 1));
    assert!(screen_rows(&screen).iter().any(|row| row.starts_with("> a3f7c01  b2")));
}

#[test]
fn only_the_row_under_the_cursor_is_marked() {
    let screen = last_screen(&then_ticks(&[with_cursor(&two_runs(), 1)], 1));
    assert_eq!(screen.text().matches("> ").count(), 1);
}

#[test]
fn the_footer_s_key_bindings_are_dim() {
    let screen = last_screen(&then_ticks(&[board(&two_runs())], 1));
    let (row, column) = find(&screen, "j/k move");
    assert_eq!(screen.cells[row][column].attrs, vec!["dim"]);
}

#[test]
fn an_empty_board_offers_only_quit() {
    let screen = last_screen(&then_ticks(&[board(&[])], 1));
    assert_eq!([screen.text().contains("q quit"), screen.text().contains("j/k move")], [true, false]);
}

#[test]
fn the_spinner_moves_on_with_each_frame() {
    let running = run(1, "running", &[("lint", "running")]);
    let screens = emulate(&frames(&then_ticks(&[board(&[running])], 2)));
    let spinner_at = |screen: &Grid| {
        let (row, column) = find(screen, "Lint ");
        screen.cells[row][column + 5].text.clone()
    };
    assert_ne!(spinner_at(&screens[0]), spinner_at(&screens[1]));
}
