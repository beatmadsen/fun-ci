//! The live session: the protocol conversation with Ruby over stdin/stdout.

use std::io::{BufRead, Write};

use crate::protocol::{Inbound, Outbound, parse};
use crate::terminal::Terminal;

/// Exit status after `quit` or end of input.
pub const EXIT_OK: i32 = 0;
/// Exit status when the terminal cannot be put into raw mode.
pub const EXIT_TERMINAL: i32 = 1;
/// Exit status when `hello` names a version this build does not speak.
pub const EXIT_VERSION: i32 = 2;

/// Runs one session to its end and returns the process exit status.
pub fn run_session<R: BufRead, W: Write, T: Terminal>(input: R, output: W, terminal: &mut T) -> i32 {
    let mut lines = input.lines().map_while(Result::ok);
    let mut session = Session { replies: Replies(output), terminal };
    match session.open(lines.next().as_deref()) {
        Ok(()) => session.converse(lines),
        Err(status) => status,
    }
}

struct Session<'t, W: Write, T: Terminal> {
    replies: Replies<W>,
    terminal: &'t mut T,
}

impl<W: Write, T: Terminal> Session<'_, W, T> {
    fn open(&mut self, hello: Option<&str>) -> Result<(), i32> {
        check_hello(hello).map_err(|detail| self.replies.refuse("version", &detail, EXIT_VERSION))?;
        let entered = self.terminal.enter();
        entered.map_err(|e| self.replies.refuse("terminal", &e.to_string(), EXIT_TERMINAL))?;
        let (cols, rows) = self.terminal.size();
        self.replies.send(&Outbound::ready(cols, rows));
        Ok(())
    }

    fn converse(&mut self, lines: impl Iterator<Item = String>) -> i32 {
        for line in lines {
            match parse(&line) {
                Ok(Inbound::Quit) => break,
                Ok(_) => {}
                Err(error) => self.replies.send(&error.reply()),
            }
        }
        self.close()
    }

    fn close(&mut self) -> i32 {
        if let Err(error) = self.terminal.restore() {
            eprintln!("fun-ci-renderer: could not restore the terminal: {error}");
        }
        EXIT_OK
    }
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
