//! What the live renderer reports on stderr, which Ruby keeps in the console
//! log: a source of input that stops for a reason other than its end, and a
//! frame that was slow to reach the terminal.

use std::cell::Cell;
use std::io::{self, Cursor, Read, Write};
use std::rc::Rc;
use std::sync::mpsc::{self, Receiver};
use std::sync::{Arc, Mutex};

use fun_ci_renderer::inputs::{Clock, Input};
use fun_ci_renderer::live_io::{read_lines, send_keys};
use fun_ci_renderer::slow_draws::SlowDraws;
use fun_ci_renderer::terminal::Terminal;

use crate::support::FakeTerminal;

/// Collects what a thread writes, for the test to read once the thread ends.
#[derive(Clone, Default)]
struct Report(Arc<Mutex<Vec<u8>>>);

impl Report {
    fn text(&self) -> String {
        String::from_utf8_lossy(&self.0.lock().unwrap()).into_owned()
    }
}

impl Write for Report {
    fn write(&mut self, bytes: &[u8]) -> io::Result<usize> {
        self.0.lock().unwrap().extend_from_slice(bytes);
        Ok(bytes.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

/// A keyboard whose next read fails.
struct Unplugged;

impl Read for Unplugged {
    fn read(&mut self, _: &mut [u8]) -> io::Result<usize> {
        Err(io::Error::other("the device went away"))
    }
}

/// Everything sent until the reading thread hangs up.
fn received(receiver: &Receiver<Input>) -> Vec<Input> {
    receiver.iter().collect()
}

fn read_ruby(input: &'static [u8]) -> (Vec<Input>, String) {
    let (sender, receiver) = mpsc::channel();
    let report = Report::default();
    read_lines(Cursor::new(input), sender, report.clone());
    (received(&receiver), report.text())
}

fn read_keyboard(keyboard: impl Read + Send + 'static) -> String {
    let (sender, receiver) = mpsc::channel();
    let report = Report::default();
    send_keys(keyboard, sender, report.clone());
    received(&receiver);
    report.text()
}

#[test]
fn ruby_s_input_that_is_not_utf8_is_reported() {
    let (_, report) = read_ruby(b"{\"t\":\"quit\"}\n\xff\n");
    assert!(report.contains("fun-ci-renderer: stopped reading Ruby's input:"), "{report}");
}

#[test]
fn ruby_s_input_that_is_not_utf8_ends_it() {
    let (inputs, _) = read_ruby(b"{\"t\":\"quit\"}\n\xff\n{\"t\":\"quit\"}\n");
    assert_eq!(inputs, vec![Input::Line(r#"{"t":"quit"}"#.into()), Input::End]);
}

#[test]
fn the_end_of_ruby_s_input_is_not_reported() {
    assert_eq!(read_ruby(b"{\"t\":\"quit\"}\n").1, "");
}

#[test]
fn a_keyboard_that_fails_is_reported_with_its_error() {
    let report = read_keyboard(Unplugged);
    assert!(report.contains("fun-ci-renderer: the keyboard stopped: the device went away"), "{report}");
}

#[test]
fn a_keyboard_that_closes_is_reported() {
    let report = read_keyboard(Cursor::new(b"q".to_vec()));
    assert!(report.contains("fun-ci-renderer: the keyboard stopped: it closed"), "{report}");
}

/// A clock the terminal below moves on as it draws.
#[derive(Clone, Default)]
struct DrawClock(Rc<Cell<u64>>);

impl Clock for DrawClock {
    fn now_ms(&self) -> u64 {
        self.0.get()
    }
}

/// A terminal that takes `ms` to take each frame.
struct Sluggish {
    inner: FakeTerminal,
    clock: DrawClock,
    ms: u64,
}

impl Terminal for Sluggish {
    fn size(&self) -> (u16, u16) {
        self.inner.size()
    }

    fn enter(&mut self) -> io::Result<()> {
        self.inner.enter()
    }

    fn restore(&mut self) -> io::Result<()> {
        self.inner.restore()
    }

    fn draw(&mut self, bytes: &[u8]) -> io::Result<()> {
        self.clock.0.set(self.clock.0.get() + self.ms);
        self.inner.draw(bytes)
    }
}

fn draw_taking(ms: u64) -> (SlowDraws<Sluggish, DrawClock, Report>, Report) {
    let clock = DrawClock::default();
    let report = Report::default();
    let terminal = Sluggish { inner: FakeTerminal::sized(80, 24), clock: clock.clone(), ms };
    let mut watched = SlowDraws::new(terminal, clock, report.clone());
    watched.draw(b"frame").unwrap();
    (watched, report)
}

#[test]
fn a_frame_that_takes_a_second_to_reach_the_terminal_is_reported() {
    let report = draw_taking(1_500).1.text();
    assert!(report.contains("fun-ci-renderer: a frame took 1500 ms to reach the terminal"), "{report}");
}

#[test]
fn a_frame_that_reaches_the_terminal_within_a_second_is_not_reported() {
    assert_eq!(draw_taking(999).1.text(), "");
}

#[test]
fn a_watched_terminal_still_draws_the_frame() {
    assert_eq!(draw_taking(0).0.into_inner().inner.frames, vec![b"frame".to_vec()]);
}
