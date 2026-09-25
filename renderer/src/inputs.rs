//! What the live session waits on, behind traits so tests drive it in
//! process: the next input (a line from Ruby, keys, a new terminal size, or a
//! frame falling due) and the wall clock.

use std::io::{BufRead, Lines};
use std::time::Duration;

/// One thing that happened, in the order the session sees them.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Input {
    /// A line from Ruby, without its newline.
    Line(String),
    /// Bytes read from the terminal.
    Keys(Vec<u8>),
    /// The terminal is now this size.
    Resize { cols: u16, rows: u16 },
    /// The wait asked for passed with nothing else happening.
    FrameDue,
    /// Ruby closed the session's input.
    End,
}

/// Where inputs come from.
pub trait Inputs {
    /// The next input, waiting at most `wait` (for ever when `None`) before
    /// answering `FrameDue`.
    fn next(&mut self, wait: Option<Duration>) -> Input;
}

/// A monotonic clock.
pub trait Clock {
    /// Milliseconds since some fixed origin.
    fn now_ms(&self) -> u64;
}

/// Ruby's lines and nothing else: no keys, no resizes, no frames falling due.
pub struct LineInputs<R: BufRead>(Lines<R>);

impl<R: BufRead> LineInputs<R> {
    #[must_use]
    pub fn new(input: R) -> Self {
        Self(input.lines())
    }
}

impl<R: BufRead> Inputs for LineInputs<R> {
    fn next(&mut self, _wait: Option<Duration>) -> Input {
        self.0.next().and_then(Result::ok).map_or(Input::End, Input::Line)
    }
}

/// A clock stopped at a time, in milliseconds.
#[derive(Debug, Default, Clone, Copy)]
pub struct StillClock(pub u64);

impl Clock for StillClock {
    fn now_ms(&self) -> u64 {
        self.0
    }
}
