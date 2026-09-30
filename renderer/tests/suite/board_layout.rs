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
    last_screen_on(lines, (80, 24))
}

/// The screen after the last of `lines`, drawn on a terminal of `size`.
fn last_screen_on(lines: &[String], size: (u16, u16)) -> Grid {
    let messages: Vec<Inbound> = lines.iter().map(|line| parse(line).unwrap()).collect();
    emulate(&replay(&messages, &Library::builtin(), size, Depth::TrueColour)).pop().unwrap()
}

#[test]
fn the_first_frame_starts_by_clearing_the_screen() {
    let frames = replay(&[parse(TICK).unwrap()], &Library::builtin(), (80, 24), Depth::TrueColour);
    assert!(frames[0].bytes.starts_with(b"\x1b[2J\x1b[H"));
}

/// Lint passes, then a frame later build passes while lint is still lit.
fn two_stages_passing() -> Vec<String> {
    vec![
        board(&[run(1, "running", "pending")]), TICK.into(),
        board(&[run(1, "passed", "running")]), event("lint"), TICK.into(),
        board(&[run(1, "passed", "passed")]), event("build"), TICK.into(),
    ]
}

#[test]
fn a_stage_effect_keeps_playing_when_another_stage_starts_one() {
    let lines = two_stages_passing();
    let unlit: Vec<String> = lines.iter().filter(|line| !line.contains("\"event\"")).cloned().collect();
    let lint = |lines: &[String]| crate::support::boards::mark(&last_screen(lines), "b1", "lint").fg;

    assert_ne!(lint(&lines), lint(&unlit));
}

#[test]
fn should_keep_the_empty_state_below_the_header_when_the_terminal_is_too_short_for_all_of_it() {
    let screen = last_screen_on(&[board(&[]), TICK.into()], (80, 18));
    assert!(screen.text().lines().nth(16).unwrap().contains("No runs yet."));
}

#[test]
fn a_screen_with_one_row_under_the_header_shows_the_keys_there() {
    let screen = last_screen_on(&[board(&[run(1, "passed", "passed")]), TICK.into()], (80, 15));
    assert!(screen.text().lines().nth(14).unwrap().contains("q quit"), "{}", screen.text());
}

#[test]
fn the_empty_state_on_a_screen_just_tall_enough_ends_with_the_quit_key_on_the_last_row() {
    let screen = last_screen_on(&[board(&[]), TICK.into()], (80, 22));
    assert!(screen.text().lines().nth(21).unwrap().contains("q quit"), "{}", screen.text());
}

/// A board with as many runs as Ruby pages for `rows` rows (renderer-protocol.md, `board`).
fn full_page(rows: u16) -> Grid {
    let runs: Vec<String> = (1..=u32::from(rows) - 18).map(|id| run(id, "passed", "passed")).collect();
    last_screen_on(&[board(&runs), TICK.into()], (80, rows))
}

#[test]
fn a_full_page_ends_with_the_footer_on_the_last_row() {
    assert!(full_page(30).text().lines().nth(29).unwrap().contains("q quit"));
}

