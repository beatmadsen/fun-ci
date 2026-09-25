//! AT-3.7 against the real binary, drawing on a pseudo-terminal named with
//! `--tty`: after end of input, `quit` or SIGTERM the terminal is out of raw
//! mode and off the alternate screen. The test waits on `ready`, on process
//! exit and on the pty closing, each with the deadline `support::renderer`
//! gives every wait on the binary.

use std::process::{ExitStatus, Stdio};

use crate::support::pty::Pty;
use crate::support::renderer::{Renderer, binary};

const LEAVE_ALTERNATE_SCREEN: &str = "\u{1b}[?1049l";
const HELLO: &str = r#"{"t":"hello","v":1}"#;

struct Outcome {
    raw_during_and_after: (bool, bool),
    replies_after_ready: String,
    drawn: String,
    status: ExitStatus,
}

fn renderer(pty: &Pty) -> Renderer {
    Renderer::start(binary().args(["--tty", &pty.path]).stderr(Stdio::null()))
}

/// The renderer, drawing on `pty`, after it has answered `ready`.
fn ready_renderer(pty: &Pty) -> Renderer {
    let mut renderer = renderer(pty);
    renderer.send(HELLO);
    let _ready = renderer.line();
    renderer
}

/// Ends the session with `end`. Input stays open until the renderer has gone
/// unless `end` closes it, so a signal is not raced by end of input.
fn ended_by(end: impl FnOnce(&mut Renderer)) -> Outcome {
    let pty = Pty::open();
    let mut renderer = ready_renderer(&pty);
    let raw_during = pty.is_raw();
    end(&mut renderer);
    let status = renderer.wait();
    let replies_after_ready = renderer.rest().concat();
    Outcome { raw_during_and_after: (raw_during, pty.is_raw()), replies_after_ready, drawn: pty.close(), status }
}

fn end_of_input(renderer: &mut Renderer) {
    renderer.close_input();
}

/// `quit`, then a line a running session would answer, then end of input,
/// so a renderer that ignored `quit` answers instead of hanging the test.
fn quit(renderer: &mut Renderer) {
    renderer.send(r#"{"t":"quit"}"#);
    renderer.send("not json");
    renderer.close_input();
}

fn sigterm(renderer: &mut Renderer) {
    unsafe { libc::kill(i32::try_from(renderer.id()).unwrap(), libc::SIGTERM) };
}

fn ready_on(pty: &Pty) -> serde_json::Value {
    let mut renderer = renderer(pty);
    renderer.send(HELLO);
    renderer.close_input();
    serde_json::from_str(&renderer.line()).unwrap()
}

#[test]
fn the_renderer_puts_its_terminal_in_raw_mode() {
    assert!(ended_by(end_of_input).raw_during_and_after.0);
}

#[test]
fn end_of_input_leaves_raw_mode() {
    assert!(!ended_by(end_of_input).raw_during_and_after.1);
}

#[test]
fn end_of_input_leaves_the_alternate_screen() {
    assert!(ended_by(end_of_input).drawn.contains(LEAVE_ALTERNATE_SCREEN));
}

#[test]
fn nothing_after_quit_is_answered() {
    assert_eq!(ended_by(quit).replies_after_ready, "");
}

#[test]
fn quit_leaves_raw_mode() {
    assert!(!ended_by(quit).raw_during_and_after.1);
}

#[test]
fn sigterm_leaves_raw_mode() {
    assert!(!ended_by(sigterm).raw_during_and_after.1);
}

#[test]
fn sigterm_leaves_the_alternate_screen() {
    assert!(ended_by(sigterm).drawn.contains(LEAVE_ALTERNATE_SCREEN));
}

#[test]
fn sigterm_exits_with_the_signal_status() {
    assert_eq!(ended_by(sigterm).status.code(), Some(143));
}

#[test]
fn ready_reports_the_terminal_width() {
    assert_eq!(ready_on(&Pty::open())["cols"], 100);
}

#[test]
fn ready_reports_the_terminal_height() {
    assert_eq!(ready_on(&Pty::open())["rows"], 30);
}

#[test]
fn a_terminal_that_reports_no_size_is_taken_as_80_columns() {
    assert_eq!(ready_on(&Pty::sized(0, 0))["cols"], 80);
}
