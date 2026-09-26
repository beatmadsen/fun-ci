//! AT-3.8 prep: the live session draws `board`s on the terminal on its own
//! clock, plays the animations `event`s call for, and tells Ruby about
//! terminal resizes (renderer-protocol.md); keys are in `live_keys`.

use std::time::Duration;

use fun_ci_renderer::grid::Emulator;
use fun_ci_renderer::inputs::Input;
use serde_json::json;

use crate::support::boards::{self, board, event, run};
use crate::support::live::{last_wait, line, live, live_on, replies_after_ready};

const TICK_0: &str = r#"{"t":"tick","ms":0}"#;
const TICK_100: &str = r#"{"t":"tick","ms":100}"#;

fn idle_board() -> String {
    board(&[run(1, "passed", &[("lint", "passed")])])
}

fn running_board() -> String {
    board(&[run(1, "running", &[("lint", "passed"), ("fast", "running")])])
}

fn failing_board() -> String {
    board(&[run(1, "failed", &[("lint", "failed")])])
}

/// A board whose one run changed status `age_s` seconds before `now`.
fn board_aged(now: i64, age_s: i64) -> String {
    let mut run = run(1, "passed", &[("lint", "passed")]);
    run["updated_at"] = json!(now - age_s);
    json!({"t": "board", "now": now, "runs": [run]}).to_string()
}

fn screen_text(frames: &[Vec<u8>]) -> String {
    let mut emulator = Emulator::new((80, 24));
    for frame in frames {
        emulator.feed((80, 24), frame);
    }
    emulator.grid().text()
}

fn headless_bytes(lines: &[&str]) -> Vec<Vec<u8>> {
    let lines: Vec<String> = lines.iter().map(ToString::to_string).collect();
    boards::frames(&lines).into_iter().map(|frame| frame.bytes).collect()
}

#[test]
fn a_board_is_drawn_on_the_terminal_when_it_arrives() {
    let frames = live(vec![line(&idle_board())]).frames;
    assert!(screen_text(&frames).contains("b1"));
}

#[test]
fn the_board_is_drawn_at_the_size_reported_in_ready() {
    let headless = headless_bytes(&[r#"{"t":"resize","cols":100,"rows":30}"#, &idle_board(), TICK_0]);
    assert_eq!(live_on((100, 30), vec![line(&idle_board())]).frames, headless);
}

#[test]
fn nothing_is_drawn_before_the_first_board() {
    assert!(live(vec![]).frames.is_empty());
}

#[test]
fn no_frame_falls_due_before_the_first_board() {
    assert_eq!(last_wait(vec![]), None);
}

#[test]
fn frames_keep_coming_at_the_busy_rate_while_a_stage_flashes() {
    let failed_run = board(&[run(1, "failed", &[("lint", "passed")])]);
    let inputs = vec![line(&failed_run), line(&event("stage_passed", 1, "lint")), Input::FrameDue];
    assert_eq!(last_wait(inputs), Some(Duration::from_millis(100)));
}

#[test]
fn a_frame_is_drawn_each_time_one_falls_due() {
    assert_eq!(live(vec![line(&idle_board()), Input::FrameDue, Input::FrameDue]).frames.len(), 3);
}

#[test]
fn a_running_run_is_redrawn_ten_times_a_second() {
    assert_eq!(last_wait(vec![line(&running_board())]), Some(Duration::from_millis(100)));
}

#[test]
fn should_redraw_an_idle_board_at_the_idle_scenes_frame_rate() {
    assert_eq!(last_wait(vec![line(&idle_board())]), Some(Duration::from_millis(250)));
}

#[test]
fn an_event_that_animates_brings_the_next_frame_to_a_tenth_of_a_second() {
    let inputs = vec![line(&failing_board()), line(&event("stage_failed", 1, "lint"))];
    assert_eq!(last_wait(inputs), Some(Duration::from_millis(100)));
}

#[test]
fn live_frames_are_the_headless_frames_for_the_same_state_and_clock() {
    let (board, failed) = (failing_board(), event("stage_failed", 1, "lint"));
    let inputs = vec![line(&board), line(&failed), Input::FrameDue, Input::FrameDue];
    let headless = headless_bytes(&[&board, TICK_0, &failed, TICK_100, TICK_100]);
    assert_eq!(live(inputs).frames, headless);
}

#[test]
fn the_clock_advances_from_the_boards_now_with_wall_time() {
    let a_second_of_idle_frames = [Input::FrameDue, Input::FrameDue, Input::FrameDue, Input::FrameDue];
    let frames = live([vec![line(&board_aged(1_790_000_000, 59))], a_second_of_idle_frames.to_vec()].concat()).frames;
    assert!(screen_text(&frames).contains("1m ago"));
}

#[test]
fn a_new_board_sets_the_clock_to_its_now() {
    let aged = board_aged(1_790_000_000, 59);
    let frames = live(vec![line(&aged), Input::FrameDue, line(&aged)]).frames;
    assert!(screen_text(&frames).contains("just now"));
}

#[test]
fn a_new_terminal_size_is_sent_to_ruby() {
    let replies = replies_after_ready(vec![Input::Resize { cols: 100, rows: 30 }]);
    assert_eq!(replies, [json!({"t":"resize","cols":100,"rows":30})]);
}

#[test]
fn a_resize_to_the_same_size_is_not_sent() {
    assert!(replies_after_ready(vec![Input::Resize { cols: 80, rows: 24 }]).is_empty());
}

#[test]
fn a_resize_redraws_at_the_new_size_at_once() {
    let inputs = vec![line(&idle_board()), Input::Resize { cols: 100, rows: 30 }];
    let headless = headless_bytes(&[&idle_board(), TICK_0, r#"{"t":"resize","cols":100,"rows":30}"#, TICK_0]);
    assert_eq!(live(inputs).frames, headless);
}

#[test]
fn a_resize_before_the_first_board_draws_nothing() {
    assert!(live(vec![Input::Resize { cols: 100, rows: 30 }]).frames.is_empty());
}

#[test]
fn quit_ends_the_session_without_drawing_again() {
    assert_eq!(live(vec![line(&idle_board()), line(r#"{"t":"quit"}"#), Input::FrameDue]).frames.len(), 1);
}
