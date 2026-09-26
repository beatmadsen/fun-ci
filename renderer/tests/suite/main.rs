//! The renderer's integration tests, one module per behaviour area, built as
//! a single test binary: each cargo-mutants mutant relinks and launches this
//! once instead of once per file.

mod support;

mod animations;
mod animator_rules;
mod binary_handshake;
mod board_layout;
mod board_look;
mod cancel_prompt;
mod cli_options;
mod clocks;
mod contract_fixtures;
mod effects;
mod format;
mod grid_difference;
mod handshake;
mod pictures;
mod playback;
mod headless;
mod headless_measures;
mod keys;
mod live;
mod live_binary;
mod protocol_version;
mod restore;
mod rows;
mod seed;
mod snapshots;
mod screen_bytes;
mod terminal_restore;
