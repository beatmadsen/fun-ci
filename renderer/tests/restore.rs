//! AT-3.7: whatever ends the session, the terminal leaves raw mode and the
//! alternate screen exactly once.

mod support;

use std::cell::RefCell;
use std::io::{self, BufRead, Read};
use std::panic::{AssertUnwindSafe, catch_unwind};

use fun_ci_renderer::session::{on_terminate, run_session};
use support::FakeTerminal;

const HELLO: &str = "{\"t\":\"hello\",\"v\":1}\n";

fn calls_after(input: &str) -> Vec<&'static str> {
    let mut terminal = FakeTerminal::sized(80, 24);
    run_session(input.as_bytes(), io::sink(), &mut terminal);
    terminal.calls
}

/// Hands out the hello line, then panics on the next read.
struct PanickingReader(&'static [u8]);

impl Read for PanickingReader {
    fn read(&mut self, _: &mut [u8]) -> io::Result<usize> {
        unreachable!("read through BufRead only")
    }
}

impl BufRead for PanickingReader {
    fn fill_buf(&mut self) -> io::Result<&[u8]> {
        assert!(!self.0.is_empty(), "the reader broke");
        Ok(self.0)
    }

    fn consume(&mut self, amount: usize) {
        self.0 = &self.0[amount..];
    }
}

#[test]
fn end_of_input_restores_the_terminal() {
    assert_eq!(calls_after(HELLO), ["enter", "restore"]);
}

#[test]
fn quit_restores_the_terminal() {
    assert_eq!(calls_after(&format!("{HELLO}{{\"t\":\"quit\"}}\n")), ["enter", "restore"]);
}

#[test]
fn nothing_after_quit_is_read() {
    let mut output = Vec::new();
    let input = format!("{HELLO}{{\"t\":\"quit\"}}\nnot json\n");
    run_session(input.as_bytes(), &mut output, &mut FakeTerminal::sized(80, 24));
    assert_eq!(String::from_utf8(output).unwrap().lines().count(), 1);
}

#[test]
fn a_panic_mid_session_restores_the_terminal() {
    let mut terminal = FakeTerminal::sized(80, 24);
    let reader = PanickingReader(HELLO.as_bytes());
    let outcome = catch_unwind(AssertUnwindSafe(|| run_session(reader, io::sink(), &mut terminal)));
    assert_eq!(outcome.err().map(|_| terminal.calls), Some(vec!["enter", "restore"]));
}

#[test]
fn a_terminating_signal_restores_before_exiting() {
    let steps = RefCell::new(Vec::new());
    on_terminate(15, || steps.borrow_mut().push("restore".to_string()), |code| steps.borrow_mut().push(format!("exit {code}")));
    assert_eq!(steps.into_inner(), ["restore", "exit 143"]);
}
