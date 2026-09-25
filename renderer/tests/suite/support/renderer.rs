//! The real renderer binary as a test's child process. Every wait on it has
//! a deadline, `PATIENCE`, after which the test fails, and dropping it (which
//! a panicking test does too) kills a renderer still running. Without both, a
//! mutant that stops the renderer exiting hangs the test until cargo-mutants'
//! timeout kills the test binary, and the renderer lives on as an orphan.

use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, ChildStdout, Command, ExitStatus, Stdio};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError};
use std::thread;
use std::time::Duration;

use wait_timeout::ChildExt;

pub const PATIENCE: Duration = Duration::from_secs(10);

pub struct Renderer {
    child: Child,
    stdin: Option<ChildStdin>,
    lines: Receiver<String>,
}

/// The renderer binary, to be given arguments and started.
#[must_use]
pub fn binary() -> Command {
    Command::new(env!("CARGO_BIN_EXE_fun-ci-renderer"))
}

impl Renderer {
    /// Starts `command` with its stdin and stdout piped to the test.
    pub fn start(command: &mut Command) -> Self {
        let mut child = command.stdin(Stdio::piped()).stdout(Stdio::piped()).spawn().unwrap();
        let (stdin, lines) = (child.stdin.take(), lines(child.stdout.take().unwrap()));
        Self { child, stdin, lines }
    }

    /// Writes `lines` and a newline in one write, so a renderer that reads
    /// them and exits never leaves part of them to a write that finds the
    /// pipe closed.
    pub fn send(&mut self, lines: &str) {
        let input = self.stdin.as_mut().expect("the renderer's input was closed");
        input.write_all(format!("{lines}\n").as_bytes()).unwrap();
    }

    /// Ends the renderer's input.
    pub fn close_input(&mut self) {
        self.stdin.take();
    }

    #[must_use]
    pub fn id(&self) -> u32 {
        self.child.id()
    }

    /// The renderer's next line.
    #[must_use]
    pub fn line(&self) -> String {
        self.lines.recv_timeout(PATIENCE).expect("no line from the renderer within the patience")
    }

    /// Whether the renderer closes its output, as it does on exiting.
    #[must_use]
    pub fn closes_output(&self) -> bool {
        matches!(self.lines.recv_timeout(PATIENCE), Err(RecvTimeoutError::Disconnected))
    }

    /// Every line the renderer writes until it closes its output.
    #[must_use]
    pub fn rest(&self) -> Vec<String> {
        let mut rest = Vec::new();
        loop {
            match self.lines.recv_timeout(PATIENCE) {
                Ok(line) => rest.push(line),
                Err(RecvTimeoutError::Disconnected) => return rest,
                Err(RecvTimeoutError::Timeout) => panic!("the renderer kept its output open past the patience"),
            }
        }
    }

    pub fn wait(&mut self) -> ExitStatus {
        self.child.wait_timeout(PATIENCE).unwrap().expect("the renderer did not exit within the patience")
    }
}

impl Drop for Renderer {
    fn drop(&mut self) {
        if let Ok(None) = self.child.try_wait() {
            let _ = self.child.kill();
            let _ = self.child.wait();
        }
    }
}

fn lines(stdout: ChildStdout) -> Receiver<String> {
    let (sender, receiver) = mpsc::channel();
    thread::spawn(move || {
        for line in BufReader::new(stdout).lines().map_while(Result::ok) {
            if sender.send(line).is_err() {
                return;
            }
        }
    });
    receiver
}
