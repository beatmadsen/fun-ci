//! A branch that starts conflicting with the trunk, or stops, plays a scene
//! from its own pool in the header, and a conflict names itself in the footer
//! (design.md, The trunk).

use serde_json::{Value, json};

use crate::support::boards::{board, event, last_screen, run, then_ticks};
use crate::support::plain_scenes::{Plain, showing};
use fun_ci_renderer::animator::Cast;

static SCENES: [Plain; 4] = [Plain("idle", None), Plain("tangle", Some(300)), Plain("untie", Some(300)),
                             Plain("explosion", Some(300))];

fn trunk_event(name: &str) -> String {
    json!({"t": "event", "name": name, "run_id": 1, "branches": 1}).to_string()
}

fn conflicting() -> Value {
    let mut conflicting = run(1, "passed", &[("fast", "passed")]);
    conflicting["branch"] = "feat/search".into();
    conflicting["trunk"] = json!({"branch_state": "conflicts", "trunk": "main"});
    conflicting
}

fn header_after(name: &str) -> String {
    showing(&SCENES, &then_ticks(&[board(&[conflicting()]), trunk_event(name)], 1))[0].clone()
}

#[test]
fn a_branch_that_starts_conflicting_plays_a_scene_of_its_pool() {
    assert!(Cast::pool("trunk_conflict").contains(&header_after("trunk_conflict").as_str()));
}

#[test]
fn a_branch_that_stops_conflicting_plays_a_scene_of_its_own_pool() {
    assert!(Cast::pool("trunk_clear").contains(&header_after("trunk_clear").as_str()));
}

#[test]
fn a_conflict_names_the_branch_and_the_trunk_in_the_footer() {
    let lines = then_ticks(&[board(&[conflicting()]), trunk_event("trunk_conflict")], 9);
    assert!(last_screen(&lines).text().contains("FEAT/SEARCH CONFLICTS WITH MAIN"));
}

#[test]
fn a_failure_banner_outranks_a_conflict_banner() {
    let mut failed = conflicting();
    failed["stages"] = json!([{"stage": "fast", "status": "failed", "duration_ms": 300}]);
    let lines = [board(&[failed]), trunk_event("trunk_conflict"), event("stage_failed", 1, "fast")];
    assert!(last_screen(&then_ticks(&lines, 9)).text().contains(">>> FAST FAILED <<<"));
}
