//! Test doubles shared by the integration tests.

use std::io;

use fun_ci_renderer::terminal::Terminal;

/// A terminal that records what the session asked of it.
#[derive(Default)]
pub struct FakeTerminal {
    pub size: (u16, u16),
    pub calls: Vec<&'static str>,
    pub drawn: Vec<u8>,
    pub fail_enter: bool,
}

impl FakeTerminal {
    pub fn sized(cols: u16, rows: u16) -> Self {
        Self { size: (cols, rows), ..Self::default() }
    }

    pub fn refusing() -> Self {
        Self { fail_enter: true, ..Self::sized(80, 24) }
    }
}

impl Terminal for FakeTerminal {
    fn size(&self) -> (u16, u16) {
        self.size
    }

    fn enter(&mut self) -> io::Result<()> {
        if self.fail_enter {
            return Err(io::Error::other("not a terminal"));
        }
        self.calls.push("enter");
        Ok(())
    }

    fn restore(&mut self) -> io::Result<()> {
        self.calls.push("restore");
        Ok(())
    }

    fn draw(&mut self, bytes: &[u8]) -> io::Result<()> {
        self.drawn.extend_from_slice(bytes);
        Ok(())
    }
}
