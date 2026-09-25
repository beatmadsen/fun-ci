//! The live session: the protocol conversation with Ruby over stdin/stdout,
//! and the console drawn on the terminal.

use std::io::{BufRead, Write};

use crate::animation::Library;
use crate::console::Console;
use crate::inputs::{Clock, Input, Inputs, LineInputs, StillClock};
use crate::live::Live;
use crate::protocol::{Inbound, Outbound, parse};
use crate::terminal::Terminal;

/// Exit status after `quit` or end of input.
pub const EXIT_OK: i32 = 0;
/// Exit status when the terminal cannot be put into raw mode.
pub const EXIT_TERMINAL: i32 = 1;
/// Exit status when `hello` names a version this build does not speak.
pub const EXIT_VERSION: i32 = 2;

/// What a live session reads, writes to Ruby, tells the time by, and draws.
pub struct Session<I: Inputs, W: Write, C: Clock> {
    pub inputs: I,
    pub output: W,
    pub clock: C,
    pub console: Console,
}

/// Runs one session on Ruby's lines alone, with a clock that stands still.
pub fn run_session<R: BufRead, W: Write, T: Terminal>(input: R, output: W, terminal: &mut T) -> i32 {
    let console = Console::new(&Library::builtin(), 0, (80, 24));
    run_live(Session { inputs: LineInputs::new(input), output, clock: StillClock, console }, terminal)
}

/// Runs one session to its end and returns the process exit status. Once
/// entered, the terminal is restored however the session ends: end of input,
/// `quit`, or a panic unwinding through here.
pub fn run_live<I: Inputs, W: Write, C: Clock, T: Terminal>(session: Session<I, W, C>, terminal: &mut T) -> i32 {
    let Session { mut inputs, output, clock, console } = session;
    let mut replies = Replies(output);
    let hello = match inputs.next(None) {
        Input::Line(line) => Some(line),
        _ => None,
    };
    match open(hello.as_deref(), &mut replies, terminal) {
        Ok(mut entered) => Live::new(console, clock).converse(&mut inputs, &mut replies, &mut entered),
        Err(status) => status,
    }
}

/// What a terminating signal does: restore the terminal, then exit with the
/// conventional `128 + signal` status.
pub fn on_terminate(signal: i32, restore: impl FnOnce(), exit: impl FnOnce(i32)) {
    restore();
    exit(128 + signal);
}

/// The terminal while the session holds it; restored when dropped.
pub struct Entered<'t, T: Terminal>(&'t mut T);

impl<T: Terminal> Entered<'_, T> {
    /// The terminal, to draw on.
    pub fn terminal(&mut self) -> &mut T {
        self.0
    }
}

impl<T: Terminal> Drop for Entered<'_, T> {
    fn drop(&mut self) {
        if let Err(error) = self.0.restore() {
            eprintln!("fun-ci-renderer: could not restore the terminal: {error}");
        }
    }
}

fn open<'t, W: Write, T: Terminal>(
    hello: Option<&str>,
    replies: &mut Replies<W>,
    terminal: &'t mut T,
) -> Result<Entered<'t, T>, i32> {
    check_hello(hello).map_err(|detail| replies.refuse("version", &detail, EXIT_VERSION))?;
    let entered = terminal.enter();
    entered.map_err(|e| replies.refuse("terminal", &e.to_string(), EXIT_TERMINAL))?;
    let (cols, rows) = terminal.size();
    replies.send(&Outbound::ready(cols, rows));
    Ok(Entered(terminal))
}

fn check_hello(line: Option<&str>) -> Result<(), String> {
    match line.map(parse) {
        Some(Ok(Inbound::Hello { v: Some(v) })) if crate::supports(v) => Ok(()),
        Some(Ok(Inbound::Hello { v: Some(v) })) => Err(format!("unsupported version {v}")),
        Some(Ok(Inbound::Hello { v: None })) => Err("hello without a version".into()),
        _ => Err(format!("expected hello, got {line:?}")),
    }
}

/// Lines to Ruby.
pub struct Replies<W: Write>(W);

impl<W: Write> Replies<W> {
    /// Writes `message` and flushes it; a failure is reported on stderr.
    pub fn send(&mut self, message: &Outbound) {
        let written = writeln!(self.0, "{}", message.line()).and_then(|()| self.0.flush());
        if let Err(error) = written {
            eprintln!("fun-ci-renderer: could not write to Ruby: {error}");
        }
    }

    fn refuse(&mut self, code: &str, detail: &str, status: i32) -> i32 {
        self.send(&Outbound::error(code, detail));
        status
    }
}
