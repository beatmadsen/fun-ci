//! The footer's words (design.md, The console): the keys that do something
//! now, the cancel prompt, what a short screen left out, and in the flat
//! layout, which projects' trunks are stale.

use fun_ci_renderer::model::Board;
use fun_ci_renderer::table::footer::{aside, keys, stale};
use serde_json::{Value, json};

const NOW: i64 = 1_790_000_000;

fn board(status: &str, extra: &Value) -> Board {
    let run = json!({"id": 1, "sha": "d4e5f67a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4", "branch": "feat/search", "project": "/src/fun-ci",
                     "status": status, "updated_at": NOW, "stages": []});
    let mut board = json!({"now": NOW, "cursor": 0, "runs": [run]});
    board.as_object_mut().unwrap().extend(extra.as_object().unwrap().clone());
    serde_json::from_value(board).unwrap()
}

#[test]
fn the_keys_offer_cancel_while_a_run_is_running() {
    assert_eq!(keys(&board("running", &json!({}))), "j/k move      c cancel      q quit");
}

#[test]
fn the_keys_offer_cancel_while_a_run_waits_to_start() {
    assert!(keys(&board("pending", &json!({}))).contains("c cancel"));
}

#[test]
fn the_keys_leave_cancel_out_when_nothing_can_be_cancelled() {
    assert_eq!(keys(&board("passed", &json!({}))), "j/k move      q quit");
}

#[test]
fn confirming_a_cancel_names_the_branch_and_short_sha() {
    assert_eq!(keys(&board("running", &json!({"confirming": true}))), "Cancel feat/search (d4e5f67)? y / n");
}

#[test]
fn the_passed_rows_a_short_screen_left_out_are_counted() {
    assert_eq!(aside(2), "2 passed not shown");
}

#[test]
fn nothing_left_out_says_nothing() {
    assert_eq!(aside(0), "");
}

#[test]
fn a_stale_trunk_is_named_with_its_project() {
    let board = board("passed", &json!({"stale_trunks": [{"project": "/src/agent-tome", "since": NOW - 7_200}]}));

    assert_eq!(stale(&board, NOW * 1000), "agent-tome: trunk last fetched 2h ago");
}

#[test]
fn each_stale_trunk_is_named() {
    let trunks = json!({"stale_trunks": [{"project": "/src/one", "since": null}, {"project": "/src/two", "since": NOW - 60}]});

    assert_eq!(stale(&board("passed", &trunks), NOW * 1000), "one: trunk could not be fetched · two: trunk last fetched 1m ago");
}

fn footer_text(width: u16, unshown: usize) -> String {
    use ratatui::widgets::Widget;
    let drawn = fun_ci_renderer::table::Drawn { lines: Vec::new(), rows: Vec::new(), columns: crate::support::paint::COLUMNS, unshown, note: None, block: None };
    let frame = fun_ci_renderer::table::Frame { width, ..crate::support::paint::frame() };
    let line = fun_ci_renderer::table::footer::footer_line(&board("passed", &json!({})), &drawn, frame);
    let mut buffer = crate::support::shown::blank(width, 1);
    line.render(buffer.area, &mut buffer);
    crate::support::shown::shown(&buffer).text()
}

#[test]
fn what_was_left_out_ends_at_the_right_margin() {
    assert_eq!(footer_text(120, 2).trim_end().chars().count(), 120 - 10);
}

#[test]
fn what_was_left_out_keeps_five_columns_from_the_keys() {
    let text = footer_text(60, 2);

    assert_eq!(text.find("2 passed"), Some(12 + "j/k move      q quit".len() + 5));
}

#[test]
fn what_was_left_out_is_cut_rather_than_run_past_the_margin() {
    assert!(footer_text(60, 2).trim_end().chars().count() <= 60 - 10);
}
