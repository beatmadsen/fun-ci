//! The fun-ci console renderer: Ruby decides what is true, this crate decides
//! how it looks. See `docs/v2/architecture.md`.

/// The renderer protocol version this build speaks (`docs/v2/renderer-protocol.md`).
pub const PROTOCOL_VERSION: u64 = 1;

/// Whether a `hello` naming `version` can be answered with `ready`.
#[must_use]
pub fn supports(version: u64) -> bool {
    version == PROTOCOL_VERSION
}
