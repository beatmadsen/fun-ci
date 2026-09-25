//! AT-3.4: for every scenario, the terminal the Rust renderer leaves behind is
//! the terminal the Ruby oracle left behind (`contract/golden/`), cell for
//! cell (text, colours, attributes), frame by frame.

use std::fs;
use std::path::PathBuf;

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::grid::Emulator;
use fun_ci_renderer::replay::{TickFrame, replay};
use fun_ci_renderer::scenario;

fn contract() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../contract")
}

fn golden(name: &str) -> Vec<Vec<u8>> {
    let mut paths: Vec<PathBuf> = fs::read_dir(contract().join("golden").join(name))
        .unwrap()
        .map(|entry| entry.unwrap().path())
        .collect();
    paths.sort();
    paths.iter().map(|path| fs::read(path).unwrap()).collect()
}

fn first_mismatch(name: &str) -> Option<String> {
    let messages = scenario::load(&contract().join("scenarios").join(format!("{name}.jsonl"))).unwrap();
    let (ours, theirs) = (replay(&messages, &Library::builtin()), golden(name));
    if ours.len() != theirs.len() {
        return Some(format!("{} frames, golden has {}", ours.len(), theirs.len()));
    }
    compare(&ours, &theirs, &scenario::tick_sizes(&messages))
}

fn compare(ours: &[TickFrame], theirs: &[Vec<u8>], sizes: &[(u16, u16)]) -> Option<String> {
    let (cols, rows) = sizes[0];
    let (mut rust, mut ruby) = (Emulator::new(cols, rows), Emulator::new(cols, rows));
    ours.iter().zip(theirs).zip(sizes).enumerate().find_map(|(i, ((our, their), &(cols, rows)))| {
        rust.feed(cols, rows, &our.bytes);
        ruby.feed(cols, rows, their);
        rust.grid().first_difference(&ruby.grid()).map(|d| format!("frame {:04}: {d}", i + 1))
    })
}

macro_rules! scenarios {
    ($($test:ident: $name:literal;)*) => {
        $(#[test] fn $test() { assert_eq!(first_mismatch($name), None); })*
    };
}

scenarios! {
    the_empty_board_matches_the_ruby_renderer: "empty";
    seven_passing_runs_match_the_ruby_renderer: "happy-7";
    a_running_pipeline_matches_the_ruby_renderer: "running";
    a_failure_explosion_matches_the_ruby_renderer: "fail-explosion";
    a_success_celebration_matches_the_ruby_renderer: "success-fireworks";
    a_sixty_column_terminal_matches_the_ruby_renderer: "narrow-60";
    a_two_hundred_column_terminal_matches_the_ruby_renderer: "wide-200";
    a_resize_during_an_animation_matches_the_ruby_renderer: "resize-mid-animation";
}
