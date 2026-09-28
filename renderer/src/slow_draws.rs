//! A terminal that reports each frame slow to reach it: a terminal that
//! stops taking output holds the renderer's only thread until it takes it
//! again, and the screen shows the last frame until then.

use std::io::{self, Write};

use crate::inputs::Clock;
use crate::terminal::Terminal;

/// How long a frame may take to reach the terminal before it is reported.
const SLOW_MS: u64 = 1_000;

/// `terminal`, with each frame slower than `SLOW_MS` by `clock` reported to `report`.
pub struct SlowDraws<T, C, W> {
    terminal: T,
    clock: C,
    report: W,
}

impl<T: Terminal, C: Clock, W: Write> SlowDraws<T, C, W> {
    #[must_use]
    pub fn new(terminal: T, clock: C, report: W) -> Self {
        Self { terminal, clock, report }
    }

    /// The terminal it watches.
    #[must_use]
    pub fn into_inner(self) -> T {
        self.terminal
    }
}

impl<T: Terminal, C: Clock, W: Write> Terminal for SlowDraws<T, C, W> {
    fn size(&self) -> (u16, u16) {
        self.terminal.size()
    }

    fn enter(&mut self) -> io::Result<()> {
        self.terminal.enter()
    }

    fn restore(&mut self) -> io::Result<()> {
        self.terminal.restore()
    }

    fn draw(&mut self, bytes: &[u8]) -> io::Result<()> {
        let started = self.clock.now_ms();
        let drawn = self.terminal.draw(bytes);
        let took = self.clock.now_ms().saturating_sub(started);
        if took >= SLOW_MS {
            let _ = writeln!(self.report, "fun-ci-renderer: a frame took {took} ms to reach the terminal");
        }
        drawn
    }
}
