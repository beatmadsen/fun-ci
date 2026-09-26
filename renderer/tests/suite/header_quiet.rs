//! AT-7.7: when nothing has run for a while, the header goes quiet.

use serde_json::Value;

use crate::support::boards::{board, frames, run, then_ticks};

const NOW: i64 = 1_790_000_000;
const QUIET: [&str; 3] = ["idle", "aurora", "fireflies"];

/// A run that ended with `status`, `ago` seconds before the board's clock.
fn ended(status: &str, ago: i64) -> Value {
    let mut ended = run(1, status, &[]);
    ended["updated_at"] = Value::from(NOW - ago);
    ended
}

fn showing(runs: &[Value]) -> String {
    frames(&then_ticks(&[board(runs)], 1)).remove(0).showing
}

#[test]
fn should_show_a_quiet_scene_five_minutes_after_the_latest_run_finished() {
    // Given a run that passed five minutes ago, and nothing running since
    let runs = [ended("passed", 300)];

    // When the console draws
    let scene = showing(&runs);

    // Then the header has gone quiet
    assert!(QUIET.contains(&scene.as_str()), "expected a quiet scene, got {scene}");
}
