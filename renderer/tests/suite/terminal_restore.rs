//! AT-3.7 against the real binary, drawing on a pseudo-terminal named with
//! `--tty`: after end of input, `quit` or SIGTERM the terminal is out of raw
//! mode and off the alternate screen. The test waits on `ready`, on process
//! exit and on the pty closing, never on time.

use std::io::{BufRead, BufReader, Read, Write};
use std::process::{Child, ChildStdin, Command, ExitStatus, Stdio};

use crate::support::pty::Pty;

const LEAVE_ALTERNATE_SCREEN: &str = "\u{1b}[?1049l";

struct Outcome {
    raw_during_and_after: (bool, bool),
    replies_after_ready: String,
    drawn: String,
    status: ExitStatus,
}

fn renderer(pty: &Pty) -> Child {
    let mut command = Command::new(env!("CARGO_BIN_EXE_fun-ci-renderer"));
    command.args(["--tty", &pty.path]).stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::null());
    command.spawn().unwrap()
}

/// The renderer, drawing on `pty`, after it has answered `ready`.
fn ready_renderer(pty: &Pty) -> (Child, Option<ChildStdin>) {
    let mut child = renderer(pty);
    let mut stdin = child.stdin.take().unwrap();
    stdin.write_all(b"{\"t\":\"hello\",\"v\":1}\n").unwrap();
    BufReader::new(child.stdout.as_mut().unwrap()).read_line(&mut String::new()).unwrap();
    (child, Some(stdin))
}

/// Ends the session with `end`. Stdin stays open until the renderer has gone
/// unless `end` closes it, so a signal is not raced by end of input.
fn ended_by(end: impl FnOnce(&mut Child, &mut Option<ChildStdin>)) -> Outcome {
    let pty = Pty::open();
    let (mut child, mut stdin) = ready_renderer(&pty);
    let raw_during = pty.is_raw();
    end(&mut child, &mut stdin);
    let status = child.wait().unwrap();
    let replies_after_ready = rest_of_stdout(&mut child);
    Outcome { raw_during_and_after: (raw_during, pty.is_raw()), replies_after_ready, drawn: pty.close(), status }
}

fn rest_of_stdout(child: &mut Child) -> String {
    let mut rest = String::new();
    child.stdout.take().unwrap().read_to_string(&mut rest).unwrap();
    rest
}

fn end_of_input(_: &mut Child, stdin: &mut Option<ChildStdin>) {
    stdin.take();
}

/// `quit`, then a line a running session would answer, then end of input,
/// so a renderer that ignored `quit` answers instead of hanging the test.
fn quit(_: &mut Child, stdin: &mut Option<ChildStdin>) {
    stdin.take().unwrap().write_all(b"{\"t\":\"quit\"}\nnot json\n").unwrap();
}

fn sigterm(child: &mut Child, _: &mut Option<ChildStdin>) {
    unsafe { libc::kill(i32::try_from(child.id()).unwrap(), libc::SIGTERM) };
}

fn ready_on(pty: &Pty) -> serde_json::Value {
    let mut child = renderer(pty);
    child.stdin.take().unwrap().write_all(b"{\"t\":\"hello\",\"v\":1}\n").unwrap();
    serde_json::from_slice(&child.wait_with_output().unwrap().stdout).unwrap()
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
