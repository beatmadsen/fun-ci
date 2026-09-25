//! Test doubles shared by the integration tests.


pub mod boards;
pub mod input;
pub mod live;
pub mod pty;
pub mod renderer;

use std::io;
use std::path::PathBuf;

use fun_ci_renderer::terminal::Terminal;

/// A terminal that records what the session asked of it.
#[derive(Default)]
pub struct FakeTerminal {
    pub size: (u16, u16),
    pub calls: Vec<&'static str>,
    pub fail_enter: bool,
    pub frames: Vec<Vec<u8>>,
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
        self.frames.push(bytes.to_vec());
        Ok(())
    }
}

/// The repository's `contract/` directory. `FUN_CI_CONTRACT` overrides it for
/// runs from a copy of `renderer/` alone, as cargo-mutants makes.
pub fn contract_dir() -> PathBuf {
    std::env::var_os("FUN_CI_CONTRACT")
        .map_or_else(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../contract"), PathBuf::from)
}
