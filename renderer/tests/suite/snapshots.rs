//! AT-5.2: what the renderer draws for each scenario in contract/scenarios,
//! frame by frame, held as a snapshot (`support::snapshot`) in
//! `snapshots/`. A change to what the TUI draws shows as a snapshot diff,
//! accepted on review with `cargo insta review`.

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::grid::{Emulator, Grid};
use fun_ci_renderer::replay::replay;
use fun_ci_renderer::scenario;

use crate::support::contract_dir;
use crate::support::snapshot::render;

fn frames(name: &str) -> Vec<Grid> {
    let messages = scenario::load(&contract_dir().join("scenarios").join(format!("{name}.jsonl"))).unwrap();
    let sizes = scenario::tick_sizes(&messages);
    let mut emulator = Emulator::new(sizes[0]);
    let drawn = replay(&messages, &Library::builtin(), (80, 24));
    drawn.iter().zip(&sizes).map(|(frame, &size)| {
        emulator.feed(size, &frame.bytes);
        emulator.grid()
    }).collect()
}

macro_rules! scenarios {
    ($($test:ident: $name:literal;)*) => {
        $(#[test] fn $test() { insta::assert_snapshot!($name, render(&frames($name))); })*
    };
}

scenarios! {
    the_empty_board_looks_as_reviewed: "empty";
    seven_passing_runs_look_as_reviewed: "happy-7";
    a_running_pipeline_looks_as_reviewed: "running";
    a_failure_explosion_looks_as_reviewed: "fail-explosion";
    a_success_celebration_looks_as_reviewed: "success-fireworks";
    a_sixty_column_terminal_looks_as_reviewed: "narrow-60";
    a_two_hundred_column_terminal_looks_as_reviewed: "wide-200";
    a_resize_during_an_animation_looks_as_reviewed: "resize-mid-animation";
}
