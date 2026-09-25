//! AT-3.2: `hello {v:1}` is answered with `ready {v:1,cols,rows}`; any other
//! version with `error {code:"version"}` and exit status 2.

use fun_ci_renderer::session::run_session;
use serde_json::{Value, json};
use crate::support::FakeTerminal;
use crate::support::input::ends_once;

const HELLO: &str = "{\"t\":\"hello\",\"v\":1}\n";

fn converse(input: &str, terminal: &mut FakeTerminal) -> (i32, Vec<Value>) {
    let mut output = Vec::new();
    let status = run_session(ends_once(input), &mut output, terminal);
    let text = String::from_utf8(output).unwrap();
    (status, text.lines().map(|l| serde_json::from_str(l).unwrap()).collect())
}

fn replies(input: &str) -> Vec<Value> {
    converse(input, &mut FakeTerminal::sized(80, 24)).1
}

fn status(input: &str) -> i32 {
    converse(input, &mut FakeTerminal::sized(80, 24)).0
}

#[test]
fn hello_v1_is_answered_with_ready_and_the_terminal_size() {
    let (_, lines) = converse(HELLO, &mut FakeTerminal::sized(120, 40));
    assert_eq!(lines, vec![json!({"t":"ready","v":1,"cols":120,"rows":40})]);
}

#[test]
fn ready_is_sent_once_the_terminal_is_in_raw_mode() {
    let mut terminal = FakeTerminal::sized(80, 24);
    converse(HELLO, &mut terminal);
    assert_eq!(terminal.calls.first(), Some(&"enter"));
}

#[test]
fn a_session_that_shook_hands_exits_zero_at_end_of_input() {
    assert_eq!(status(HELLO), 0);
}

#[test]
fn an_unsupported_version_is_answered_with_a_version_error() {
    assert_eq!(replies("{\"t\":\"hello\",\"v\":2}\n")[0]["code"], "version");
}

#[test]
fn an_unsupported_version_gets_no_ready() {
    assert_eq!(replies("{\"t\":\"hello\",\"v\":2}\n").len(), 1);
}

#[test]
fn an_unsupported_version_exits_with_status_two() {
    assert_eq!(status("{\"t\":\"hello\",\"v\":2}\n"), 2);
}

#[test]
fn an_unsupported_version_leaves_the_terminal_untouched() {
    let mut terminal = FakeTerminal::sized(80, 24);
    converse("{\"t\":\"hello\",\"v\":2}\n", &mut terminal);
    assert!(terminal.calls.is_empty());
}

#[test]
fn a_hello_without_a_version_exits_with_status_two() {
    assert_eq!(status("{\"t\":\"hello\"}\n"), 2);
}

#[test]
fn a_version_error_names_the_version_asked_for() {
    assert_eq!(replies("{\"t\":\"hello\",\"v\":2}\n")[0]["detail"], "unsupported version 2");
}

#[test]
fn a_version_error_says_when_hello_has_no_version() {
    assert_eq!(replies("{\"t\":\"hello\"}\n")[0]["detail"], "hello without a version");
}

#[test]
fn a_message_before_hello_exits_with_status_two() {
    assert_eq!(status("{\"t\":\"quit\"}\n"), 2);
}

#[test]
fn a_line_that_is_not_json_is_answered_with_a_parse_error() {
    assert_eq!(replies(&format!("{HELLO}not json\n"))[1]["code"], "parse");
}

#[test]
fn a_message_without_a_type_is_answered_with_a_parse_error() {
    assert_eq!(replies(&format!("{HELLO}{{\"v\":1}}\n"))[1]["code"], "parse");
}

#[test]
fn a_message_of_unknown_type_is_answered_with_an_unknown_type_error() {
    assert_eq!(replies(&format!("{HELLO}{{\"t\":\"dance\"}}\n"))[1]["code"], "unknown_type");
}

#[test]
fn an_unknown_type_error_names_the_type() {
    assert_eq!(replies(&format!("{HELLO}{{\"t\":\"dance\"}}\n"))[1]["detail"], "dance");
}

#[test]
fn the_session_carries_on_after_a_bad_line() {
    assert_eq!(replies(&format!("{HELLO}not json\n{{\"t\":\"dance\"}}\n")).len(), 3);
}

#[test]
fn a_terminal_that_cannot_enter_raw_mode_is_reported_as_a_terminal_error() {
    let (_, lines) = converse(HELLO, &mut FakeTerminal::refusing());
    assert_eq!(lines[0]["code"], "terminal");
}

#[test]
fn a_terminal_that_cannot_enter_raw_mode_exits_with_status_one() {
    let (status, _) = converse(HELLO, &mut FakeTerminal::refusing());
    assert_eq!(status, 1);
}
