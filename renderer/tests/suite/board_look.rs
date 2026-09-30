//! How the board shows the footer and the spinner, as the 1.x console's
//! Cucumber features specified them; the cursor's block is in `quiet_table`.

use fun_ci_renderer::grid::Grid;
use serde_json::Value;

use crate::support::boards::{board, frames, last_screen, run, then_ticks};
use fun_ci_renderer::headless::emulate;

fn two_runs() -> Vec<Value> {
    vec![run(1, "passed", &[("lint", "passed")]), run(2, "passed", &[("lint", "passed")])]
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
fn the_footer_s_keys_are_quiet() {
    let screen = last_screen(&then_ticks(&[board(&two_runs())], 1));
    let (row, column) = find(&screen, "j/k move");
    let [r, g, b] = fun_ci_renderer::table::night::QUIET;
    assert_eq!(screen.cells[row][column].fg, fun_ci_renderer::grid::Colour::Rgb(r, g, b));
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
    let spinner_at = |screen: &Grid| crate::support::boards::mark(screen, "b1", "lint").text;
    assert_ne!(spinner_at(&screens[0]), spinner_at(&screens[1]));
}

#[test]
fn every_spinner_frame_is_heavier_than_the_dot_of_a_stage_not_reached() {
    let mut spinner = fun_ci_renderer::spinner::Spinner::default();
    let dots: Vec<u32> = (0..16).map(|_| { spinner.advance(); (u32::from(spinner.current()) - 0x2800).count_ones() }).collect();
    assert!(dots.iter().all(|&n| n >= 3), "{dots:?}");
}
