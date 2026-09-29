//! Protocol lines for small hand-made scenarios, and what they leave on an
//! 80x24 screen.

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::grid::Grid;
use fun_ci_renderer::headless::emulate;
use fun_ci_renderer::protocol::{Inbound, parse};
use fun_ci_renderer::replay::{TickFrame, replay};
use serde_json::{Value, json};

pub const TICK: &str = r#"{"t":"tick","ms":100}"#;

/// Run `id` (branch `b<id>`) with each `(stage, status)` taking 300 ms.
pub fn run(id: u64, status: &str, stages: &[(&str, &str)]) -> Value {
    let stages: Vec<Value> = stages.iter().map(|(s, st)| json!({"stage": s, "status": st, "duration_ms": 300})).collect();
    let sha = format!("a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4c6d8e0{id}");
    json!({"id": id, "sha": sha, "branch": format!("b{id}"), "status": status, "updated_at": 1_790_000_000, "stages": stages})
}

pub fn board(runs: &[Value]) -> String {
    json!({"t": "board", "now": 1_790_000_000, "cursor": null, "runs": runs}).to_string()
}

pub fn event(name: &str, run_id: u64, stage: &str) -> String {
    json!({"t": "event", "name": name, "run_id": run_id, "stage": stage}).to_string()
}

/// `lines` followed by `ticks` ticks.
pub fn then_ticks(lines: &[String], ticks: usize) -> Vec<String> {
    lines.iter().cloned().chain(std::iter::repeat_n(TICK.to_string(), ticks)).collect()
}

pub fn frames(lines: &[String]) -> Vec<TickFrame> {
    let messages: Vec<Inbound> = lines.iter().map(|line| parse(line).unwrap()).collect();
    replay(&messages, &Library::builtin(), (80, 24), Depth::TrueColour)
}

/// The screen after the last of `lines`.
pub fn last_screen(lines: &[String]) -> Grid {
    emulate(&frames(lines)).pop().unwrap()
}

/// The screen row of the table's heading, which names each stage over its column.
pub const HEADING_ROW: usize = 15;

/// The column `stage`'s cells start at, as the heading names it.
pub fn stage_column(screen: &Grid, stage: &str) -> usize {
    let heading = screen.text().lines().nth(HEADING_ROW).unwrap().to_string();
    heading[..heading.find(stage).unwrap_or_else(|| panic!("no {stage:?} in {heading:?}"))].chars().count()
}

/// Whether the first cell of `stage`'s column on screen row `row` is bold.
pub fn bold_at_stage(screen: &Grid, row: usize, stage: &str) -> bool {
    screen.cells[row][stage_column(screen, stage)].attrs.contains(&"bold")
}
