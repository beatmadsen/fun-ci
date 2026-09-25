//! AT-3.5: each contract fixture (`contract/fixtures/*.jsonl`) is a
//! conversation both suites hold. Given the fixture's Ruby lines, and the
//! terminal's keys and sizes behind its renderer lines, the live session
//! answers with exactly the fixture's renderer lines, in order. Ruby holds
//! the other side in `test/acceptance/test_contract_fixtures.rb`.

use std::collections::VecDeque;
use std::fs;

use fun_ci_renderer::inputs::Input;
use serde_json::Value;

use crate::support::contract_dir;
use crate::support::live::converse;

const FIXTURES: [&str; 4] = ["cancel", "happy-7", "resize", "stage-failed"];

fn fixture(name: &str) -> Vec<Value> {
    let path = contract_dir().join("fixtures").join(format!("{name}.jsonl"));
    fs::read_to_string(path).unwrap().lines().map(|line| serde_json::from_str(line).unwrap()).collect()
}

/// The bytes a terminal sends for a protocol key name.
fn typed(key: &str) -> Vec<u8> {
    match key {
        "up" => b"\x1b[A".to_vec(),
        "down" => b"\x1b[B".to_vec(),
        "enter" => b"\r".to_vec(),
        "esc" => b"\x1b".to_vec(),
        "ctrl_c" => b"\x03".to_vec(),
        printable => printable.as_bytes().to_vec(),
    }
}

/// What makes the renderer write `message`; `ready` answers `hello` unasked.
fn cause(message: &Value) -> Option<Input> {
    let size = |field: &str| u16::try_from(message[field].as_u64().unwrap()).unwrap();
    match message["t"].as_str().unwrap() {
        "key" => Some(Input::Keys(typed(message["key"].as_str().unwrap()))),
        "resize" => Some(Input::Resize { cols: size("cols"), rows: size("rows") }),
        _ => None,
    }
}

fn input(line: &Value) -> Option<Input> {
    line.get("ruby").map(|message| Input::Line(message.to_string())).or_else(|| line.get("renderer").and_then(cause))
}

fn renderer_lines(lines: &[Value]) -> Vec<Value> {
    lines.iter().filter_map(|line| line.get("renderer").cloned()).collect()
}

/// The terminal's size, as the fixture's `ready` reports it.
fn terminal_size(lines: &[Value]) -> (u16, u16) {
    let ready = renderer_lines(lines).into_iter().find(|message| message["t"] == "ready").unwrap();
    let size = |field: &str| u16::try_from(ready[field].as_u64().unwrap()).unwrap();
    (size("cols"), size("rows"))
}

fn holds(name: &str) {
    let lines = fixture(name);
    let inputs: VecDeque<Input> = lines.iter().filter_map(input).collect();
    assert_eq!(converse(terminal_size(&lines), inputs).replies, renderer_lines(&lines), "{name}");
}

#[test]
fn every_fixture_is_held_here() {
    let mut names: Vec<String> = fs::read_dir(contract_dir().join("fixtures"))
        .unwrap()
        .map(|entry| entry.unwrap().path().file_stem().unwrap().to_string_lossy().into_owned())
        .collect();
    names.sort();
    assert_eq!(names, FIXTURES);
}

#[test]
fn the_renderer_holds_the_cancel_conversation() {
    holds("cancel");
}

#[test]
fn the_renderer_holds_the_happy_7_conversation() {
    holds("happy-7");
}

#[test]
fn the_renderer_holds_the_resize_conversation() {
    holds("resize");
}

#[test]
fn the_renderer_holds_the_stage_failed_conversation() {
    holds("stage-failed");
}
