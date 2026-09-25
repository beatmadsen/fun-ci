//! The live session: the protocol conversation with Ruby over stdin/stdout.

use std::io::{BufRead, Write};

use crate::protocol::{Inbound, Outbound, ParseError, parse};
use crate::terminal::Terminal;

/// Exit status after `quit` or end of input.
pub const EXIT_OK: i32 = 0;
/// Exit status when the terminal cannot be put into raw mode.
pub const EXIT_TERMINAL: i32 = 1;
/// Exit status when `hello` names a version this build does not speak.
pub const EXIT_VERSION: i32 = 2;

/// Runs one session to its end and returns the process exit status. Once
/// entered, the terminal is restored however the session ends: end of input,
/// `quit`, or a panic unwinding through here.
pub fn run_session<R: BufRead, W: Write, T: Terminal>(input: R, output: W, terminal: &mut T) -> i32 {
    let mut lines = input.lines().map_while(Result::ok);
    let mut replies = Replies(output);
    match open(lines.next().as_deref(), &mut replies, terminal) {
        Ok(entered) => converse(&entered, lines, &mut replies),
        Err(status) => status,
    }
}

/// What a terminating signal does: restore the terminal, then exit with the
/// conventional `128 + signal` status.
pub fn on_terminate(signal: i32, restore: impl FnOnce(), exit: impl FnOnce(i32)) {
    restore();
    exit(128 + signal);
}

struct Entered<'t, T: Terminal>(&'t mut T);

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

fn converse<W: Write, T: Terminal>(
    _entered: &Entered<T>,
    lines: impl Iterator<Item = String>,
    replies: &mut Replies<W>,
) -> i32 {
    for line in lines {
        if !handle(parse(&line), replies) {
            break;
        }
    }
    EXIT_OK
}

fn handle<W: Write>(message: Result<Inbound, ParseError>, replies: &mut Replies<W>) -> bool {
    match message {
        Ok(Inbound::Quit) => return false,
        Ok(_) => {}
        Err(error) => replies.send(&error.reply()),
    }
    true
}

fn check_hello(line: Option<&str>) -> Result<(), String> {
    match line.map(parse) {
        Some(Ok(Inbound::Hello { v: Some(v) })) if crate::supports(v) => Ok(()),
        Some(Ok(Inbound::Hello { v: Some(v) })) => Err(format!("unsupported version {v}")),
        Some(Ok(Inbound::Hello { v: None })) => Err("hello without a version".into()),
        _ => Err(format!("expected hello, got {line:?}")),
    }
}

struct Replies<W: Write>(W);

impl<W: Write> Replies<W> {
    fn send(&mut self, message: &Outbound) {
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
