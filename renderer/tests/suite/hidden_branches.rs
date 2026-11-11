//! Hidden branches on the screen (design.md, The console; acceptance-tests.md,
//! AT-13.33): `h` hides the branch under the cursor as it does a job; once
//! shown, a hidden branch's row is pale and unstriped, says how it was hidden,
//! and doesn't need you.

use crate::support::quiet::{NOW, failed, paper, passed, screen_with, unstriped};
use fun_ci_renderer::grid::{Colour, Grid};
use fun_ci_renderer::table::night::INDIGO;
use serde_json::{Value, json};

fn hidden(mut run: Value, how: &str) -> Value {
    run["hidden"] = json!(how);
    run
}

/// `runs` on a screen of `size`, with `more` of a board's fields.
fn shown(runs: &[Value], more: &Value, size: (u16, u16)) -> Grid {
    let mut board = json!({"t": "board", "now": NOW, "cursor": null, "runs": runs});
    board.as_object_mut().unwrap().extend(more.as_object().unwrap().clone());
    screen_with(&board, size)
}

fn footer(grid: &Grid) -> String {
    grid.text().lines().last().unwrap().trim_end().to_string()
}

fn line_of(grid: &Grid, name: &str) -> String {
    let text = grid.text();
    text.lines().find(|line| unstriped(line).starts_with(name)).unwrap_or_else(|| panic!("no {name:?} in\n{text}")).to_string()
}

fn feat_hidden_and_main() -> Vec<Value> {
    vec![hidden(failed(2, "feat", "/src/app"), "snoozed"), passed(1, "main", "/src/app")]
}

#[test]
fn the_footer_offers_to_hide_the_branch_under_the_cursor() {
    let grid = shown(&[failed(2, "feat", "/src/app")], &json!({"cursor": 0}), (120, 40));

    assert!(footer(&grid).contains("h  hide"), "{}", grid.text());
}

#[test]
fn the_footer_offers_to_show_a_hidden_branch_under_the_cursor() {
    let grid = shown(&feat_hidden_and_main(), &json!({"cursor": 0, "hidden_rows": 1}), (120, 40));

    assert!(footer(&grid).contains("h  show"), "{}", grid.text());
}

#[test]
fn hiding_a_branch_asks_about_it_by_name() {
    let grid = shown(&[failed(2, "feat", "/src/app")], &json!({"cursor": 0, "hiding": true}), (120, 40));

    assert!(footer(&grid).contains("Hide feat?"), "{}", grid.text());
}

#[test]
fn a_hidden_branch_s_row_says_how_it_was_hidden() {
    let grid = shown(&feat_hidden_and_main(), &json!({"hidden_rows": 1}), (120, 40));

    assert!(line_of(&grid, "feat").contains("snoozed until its next run"), "{}", grid.text());
}

#[test]
fn a_hidden_branch_that_failed_has_no_stripe() {
    let grid = shown(&feat_hidden_and_main(), &json!({"hidden_rows": 1}), (120, 40));

    assert!(!line_of(&grid, "feat").trim_start().starts_with('▌'), "{}", grid.text());
}

#[test]
fn a_hidden_branch_that_failed_under_the_cursor_leaves_the_block_calm() {
    let grid = shown(&feat_hidden_and_main(), &json!({"cursor": 0, "hidden_rows": 1}), (120, 40));

    assert_eq!(paper(&grid), Colour::Rgb(INDIGO[0], INDIGO[1], INDIGO[2]));
}

#[test]
fn the_footer_says_how_many_rows_are_hidden() {
    let grid = shown(&[passed(1, "main", "/src/app")], &json!({"hidden_rows": 2}), (120, 40));

    assert!(footer(&grid).ends_with("a shows 2 hidden rows"), "{}", grid.text());
}
