//! The fun-ci console renderer: Ruby decides what is true, this crate decides
//! how it looks. See `docs/v2/architecture.md`.

pub mod animation;
pub mod animator;
pub mod ansi;
pub mod board_view;
pub mod cli;
pub mod console;
pub mod format;
pub mod grid;
pub mod headless;
pub mod inputs;
pub mod keys;
pub mod live;
pub mod live_io;
pub mod model;
pub mod protocol;
pub mod replay;
pub mod row;
pub mod scenario;
pub mod screen;
pub mod session;
pub mod spinner;
pub mod terminal;
pub mod tty;

/// The renderer protocol version this build speaks (`docs/v2/renderer-protocol.md`).
pub const PROTOCOL_VERSION: u64 = 1;

/// Whether a `hello` naming `version` can be answered with `ready`.
#[must_use]
pub fn supports(version: u64) -> bool {
    version == PROTOCOL_VERSION
}
