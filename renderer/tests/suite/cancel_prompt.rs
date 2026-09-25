//! AT-3.7b: the cancel prompt names the run it would cancel.

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::grid::Emulator;
use fun_ci_renderer::protocol::parse;
use fun_ci_renderer::replay::replay;

const RUN: &str = r#"{"id":1,"sha":"d4e5f67a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4","branch":"feat/search",
  "status":"running","updated_at":1790000000,"stages":[]}"#;

/// The footer line of a board with one running run.
fn footer(cursor: &str, confirming: bool) -> String {
    let board = format!(r#"{{"t":"board","now":1790000000,"cursor":{cursor},"confirming":{confirming},"runs":[{RUN}]}}"#);
    let messages = [parse(&board.replace('\n', "")).unwrap(), parse(r#"{"t":"tick","ms":100}"#).unwrap()];
    let frame = &replay(&messages, &Library::builtin(), (80, 24))[0];
    let mut terminal = Emulator::new(frame.size);
    terminal.feed(frame.size, &frame.bytes);
    terminal.grid().text().lines().nth(16).unwrap().trim_end().to_string()
}

#[test]
fn the_prompt_names_the_branch_and_short_sha_of_the_run_under_the_cursor() {
    assert_eq!(footer("0", true), "  Cancel feat/search (d4e5f67)? y / n");
}

#[test]
fn without_a_run_under_the_cursor_there_is_nothing_to_confirm() {
    assert_eq!(footer("5", true), "  j/k move   c cancel   q quit");
}

#[test]
fn a_board_that_is_not_confirming_shows_the_key_bindings() {
    assert_eq!(footer("0", false), "  j/k move   c cancel   q quit");
}
