//! Layout rules the eight golden scenarios do not reach: truncation to the
//! terminal height, and effects on two stages at once.

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::grid::Grid;
use fun_ci_renderer::headless::emulate;
use fun_ci_renderer::protocol::{Inbound, parse};
use fun_ci_renderer::replay::replay;

const TICK: &str = r#"{"t":"tick","ms":100}"#;

fn run(id: u32, lint: &str, build: &str) -> String {
    format!(
        r#"{{"id":{id},"sha":"a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4c6d8e0{id}","branch":"b{id}","status":"running",
        "updated_at":1790000000,"stages":[{{"stage":"lint","status":"{lint}","duration_ms":300}},
        {{"stage":"build","status":"{build}","duration_ms":300}}]}}"#
    )
}

fn board(runs: &[String]) -> String {
    format!(r#"{{"t":"board","now":1790000000,"cursor":null,"runs":[{}]}}"#, runs.join(",")).replace('\n', "")
}

fn event(stage: &str) -> String {
    format!(r#"{{"t":"event","name":"stage_passed","run_id":1,"stage":"{stage}"}}"#)
}

/// The screen after the last of `lines`, drawn on an 80x24 terminal.
fn last_screen(lines: &[String]) -> Grid {
    let messages: Vec<Inbound> = lines.iter().map(|line| parse(line).unwrap()).collect();
    emulate(&replay(&messages, &Library::builtin(), (80, 24), Depth::TrueColour)).pop().unwrap()
}

fn six_runs_on_24_rows() -> String {
    let runs: Vec<String> = (1..=6).map(|id| run(id, "passed", "passed")).collect();
    last_screen(&[board(&runs), TICK.into()]).text()
}

#[test]
fn the_first_frame_starts_by_clearing_the_screen() {
    let frames = replay(&[parse(TICK).unwrap()], &Library::builtin(), (80, 24), Depth::TrueColour);
    assert!(frames[0].bytes.starts_with(b"\x1b[2J\x1b[H"));
}

#[test]
fn a_24_row_terminal_shows_the_fourth_run() {
    assert!(six_runs_on_24_rows().contains("  b4  "));
}

#[test]
fn a_24_row_terminal_leaves_out_the_fifth_run() {
    assert!(!six_runs_on_24_rows().contains("  b5  "));
}

/// Lint passes, then a frame later build passes while lint still flashes.
fn two_stages_passing() -> Vec<String> {
    vec![
        board(&[run(1, "running", "pending")]), TICK.into(),
        board(&[run(1, "passed", "running")]), event("lint"), TICK.into(),
        board(&[run(1, "passed", "passed")]), event("build"), TICK.into(),
    ]
}

#[test]
fn a_stage_effect_keeps_playing_when_another_stage_starts_one() {
    let lint = &last_screen(&two_stages_passing()).cells[14][15];
    assert_eq!((lint.text.as_str(), lint.attrs.clone()), ("L", vec!["bold"]));
}
