//! The real terminal: `/dev/tty`, so the stdin/stdout pipes never carry
//! terminal bytes. Opened on `enter`, so a refused handshake never touches it.

use std::fs::{File, OpenOptions};
use std::io::{self, Write};

use crossterm::{cursor, execute, terminal};

use crate::terminal::Terminal;

/// The controlling terminal of this process.
#[derive(Default)]
pub struct Tty {
    out: Option<File>,
}

impl Terminal for Tty {
    fn size(&self) -> (u16, u16) {
        terminal::size().unwrap_or((80, 24))
    }

    fn enter(&mut self) -> io::Result<()> {
        let mut out = OpenOptions::new().write(true).open("/dev/tty")?;
        terminal::enable_raw_mode()?;
        execute!(out, terminal::EnterAlternateScreen, cursor::Hide)?;
        self.out = Some(out);
        Ok(())
    }

    fn restore(&mut self) -> io::Result<()> {
        let Some(mut out) = self.out.take() else {
            return Ok(());
        };
        execute!(out, cursor::Show, terminal::LeaveAlternateScreen)?;
        terminal::disable_raw_mode()
    }

    fn draw(&mut self, bytes: &[u8]) -> io::Result<()> {
        let out = self.out.as_mut().ok_or_else(|| io::Error::other("terminal not entered"))?;
        out.write_all(bytes)?;
        out.flush()
    }
}
