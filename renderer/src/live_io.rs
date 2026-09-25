//! The real sources of a live session's inputs: threads that read Ruby's
//! lines, the terminal's keys and its size changes (SIGWINCH) into one
//! channel, which the session waits on with a timeout for the next frame.

use std::io::{self, BufRead, Read};
use std::path::PathBuf;
use std::sync::mpsc::{Receiver, RecvTimeoutError, Sender};
use std::thread;
use std::time::{Duration, Instant};

use signal_hook::consts::SIGWINCH;
use signal_hook::iterator::Signals;

use crate::inputs::{Clock, Input, Inputs};
use crate::terminal::Terminal;
use crate::tty::{self, Tty};

/// Inputs as the reader threads send them.
pub struct ChannelInputs(Receiver<Input>);

impl ChannelInputs {
    #[must_use]
    pub fn new(receiver: Receiver<Input>) -> Self {
        Self(receiver)
    }
}

impl Inputs for ChannelInputs {
    fn next(&mut self, wait: Option<Duration>) -> Input {
        let Some(wait) = wait else { return self.0.recv().unwrap_or(Input::End) };
        match self.0.recv_timeout(wait) {
            Ok(input) => input,
            Err(RecvTimeoutError::Timeout) => Input::FrameDue,
            Err(RecvTimeoutError::Disconnected) => Input::End,
        }
    }
}

/// Sends each line of `input`, then `End`, from a thread of its own.
pub fn read_lines(input: impl BufRead + Send + 'static, sender: Sender<Input>) {
    thread::spawn(move || {
        for line in input.lines().map_while(Result::ok) {
            if sender.send(Input::Line(line)).is_err() {
                return;
            }
        }
        let _ = sender.send(Input::End);
    });
}

/// Wall time since the session started.
pub struct WallClock(Instant);

impl WallClock {
    #[must_use]
    pub fn start() -> Self {
        Self(Instant::now())
    }
}

impl Clock for WallClock {
    fn now_ms(&self) -> u64 {
        u64::try_from(self.0.elapsed().as_millis()).unwrap_or(u64::MAX)
    }
}

/// The terminal device, which once entered also sends its keys and its new
/// sizes as inputs.
pub struct LiveTty {
    tty: Tty,
    sender: Sender<Input>,
}

impl LiveTty {
    #[must_use]
    pub fn new(path: PathBuf, sender: Sender<Input>) -> Self {
        Self { tty: Tty::new(path), sender }
    }
}

impl Terminal for LiveTty {
    fn size(&self) -> (u16, u16) {
        self.tty.size()
    }

    fn enter(&mut self) -> io::Result<()> {
        self.tty.enter()?;
        send_keys(tty::keyboard()?, self.sender.clone());
        send_resizes(Signals::new([SIGWINCH])?, self.sender.clone());
        Ok(())
    }

    fn restore(&mut self) -> io::Result<()> {
        self.tty.restore()
    }

    fn draw(&mut self, bytes: &[u8]) -> io::Result<()> {
        self.tty.draw(bytes)
    }
}

fn send_keys(mut keyboard: impl Read + Send + 'static, sender: Sender<Input>) {
    thread::spawn(move || {
        let mut chunk = [0; 64];
        while let Ok(read @ 1..) = keyboard.read(&mut chunk) {
            if sender.send(Input::Keys(chunk[..read].to_vec())).is_err() {
                return;
            }
        }
    });
}

fn send_resizes(mut signals: Signals, sender: Sender<Input>) {
    thread::spawn(move || {
        for _ in signals.forever() {
            let (cols, rows) = tty::entered_size();
            if sender.send(Input::Resize { cols, rows }).is_err() {
                return;
            }
        }
    });
}
