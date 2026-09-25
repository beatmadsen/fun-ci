//! The renderer's integration tests, one module per behaviour area, built as
//! a single test binary: each cargo-mutants mutant relinks and launches this
//! once instead of once per file.

mod support;

mod animations;
mod animator_rules;
mod binary_handshake;
mod board_layout;
mod cancel_prompt;
mod cli_options;
mod differential;
mod effects;
mod format;
mod grid_difference;
mod handshake;
mod pictures;
mod headless;
mod headless_measures;
mod keys;
mod live;
mod protocol_version;
mod restore;
mod screen_bytes;
mod terminal_restore;
