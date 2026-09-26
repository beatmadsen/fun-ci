//! The renderer's integration tests, one module per behaviour area, built as
//! a single test binary: each cargo-mutants mutant relinks and launches this
//! once instead of once per file.

mod support;

mod animator_rules;
mod binary_handshake;
mod board_layout;
mod board_look;
mod cell_encoding;
mod cell_output;
mod cancel_prompt;
mod canvas;
mod cli_options;
mod clocks;
mod contract_fixtures;
mod effects;
mod film;
mod format;
mod grid_difference;
mod handshake;
mod painting;
mod pictures;
mod portable_maths;
mod header_queue;
mod header_rest;
mod header_scenes;
mod headless;
mod headless_measures;
mod keys;
mod live;
mod live_binary;
mod live_keys;
mod protocol_version;
mod restore;
mod rows;
mod seed;
mod snapshot_text;
mod snapshots;
mod scene_pools;
mod scenes;
mod screen_bytes;
mod terminal_restore;
