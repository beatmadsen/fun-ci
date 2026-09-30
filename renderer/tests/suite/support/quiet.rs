//! Boards and screens for the quiet table's acceptance tests: runs as Ruby
//! sends them, the screen once they arrive, and what the screen says.

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::grid::{Colour, Grid};
use fun_ci_renderer::headless::emulate;
use fun_ci_renderer::protocol::parse;
use fun_ci_renderer::replay::replay;
use serde_json::{Value, json};

pub const NOW: i64 = 1_790_000_000;
/// The rows the header takes.
pub const HEADER: usize = 14;

pub fn stage(name: &str, status: &str, ms: u64) -> Value {
    json!({"stage": name, "status": status, "duration_ms": ms})
}

pub fn run(id: u64, (branch, project): (&str, &str), status: &str, stages: &[Value]) -> Value {
    json!({"id": id, "sha": format!("{id:040}"), "branch": branch, "project": project,
           "status": status, "updated_at": NOW - 360, "stages": stages})
}

pub fn passed(id: u64, branch: &str, project: &str) -> Value {
    run(id, (branch, project), "passed", &["lint", "build", "fast", "slow"].map(|s| stage(s, "passed", 1_200)))
}

pub fn failed(id: u64, branch: &str, project: &str) -> Value {
    run(id, (branch, project), "failed", &[stage("lint", "passed", 300), stage("build", "passed", 900), stage("fast", "failed", 1_400)])
}

/// The screen once `runs` are on the board, `cols` wide and `rows` high.
pub fn screen(runs: &[Value], size: (u16, u16)) -> Grid {
    screen_with(&json!({"t": "board", "now": NOW, "cursor": null, "runs": runs}), size)
}

/// The screen once `board` has arrived, `cols` wide and `rows` high.
pub fn screen_with(board: &Value, (cols, rows): (u16, u16)) -> Grid {
    let board = board.to_string();
    let messages = [parse(&board).unwrap(), parse(r#"{"t":"tick","ms":100}"#).unwrap()];
    emulate(&replay(&messages, &Library::builtin(), (cols, rows), Depth::TrueColour)).pop().unwrap()
}

/// The screen's lines below the header that say something, trimmed, each cut
/// at its first wide gap: a label whole, a row by its branch. The block's
/// edges, lines of half blocks, say nothing.
pub fn said(grid: &Grid) -> Vec<String> {
    let lines: Vec<String> = grid.text().lines().skip(HEADER).map(|l| l.trim().to_string()).collect();
    let saying = |line: &String| line.chars().any(|c| !matches!(c, '▄' | '▀' | ' '));
    lines.into_iter().filter(saying).map(|l| l.split("  ").next().unwrap_or_default().to_string()).collect()
}

/// The screen rows whose cell at the block's left edge is on the block's paper.
pub fn in_the_block(grid: &Grid) -> Vec<String> {
    let rows = grid.cells.iter().enumerate().skip(HEADER);
    let on_paper = rows.filter(|(_, cells)| cells.iter().any(|cell| cell.bg != Colour::Default));
    on_paper.map(|(row, _)| grid.text().lines().nth(row).unwrap().trim().split("  ").next().unwrap().to_string()).collect()
}

pub fn board(runs: &[Value], cursor: Option<usize>) -> Value {
    json!({"t": "board", "now": NOW, "cursor": cursor, "runs": runs})
}

/// The screen after `ticks` ticks of a tenth of a second.
pub fn screen_after(board: &Value, ticks: usize, (cols, rows): (u16, u16)) -> Grid {
    let tick = parse(r#"{"t":"tick","ms":100}"#).unwrap();
    let messages: Vec<_> = std::iter::once(parse(&board.to_string()).unwrap()).chain(std::iter::repeat_n(tick, ticks)).collect();
    emulate(&replay(&messages, &Library::builtin(), (cols, rows), Depth::TrueColour)).pop().unwrap()
}

/// The colour of the block's paper on screen.
pub fn paper(grid: &Grid) -> Colour {
    grid.cells.iter().skip(HEADER).flatten().map(|cell| cell.bg).find(|bg| *bg != Colour::Default).unwrap()
}

/// Two projects of six branches, a failure and five passes each.
pub fn two_crowded_projects() -> Vec<Value> {
    let project = |base: u64, name: &str| {
        let path = format!("/src/{name}");
        let passes: Vec<Value> = (1..=5).map(|n| passed(base + n, &format!("{name}-{n}"), &path)).collect();
        std::iter::once(failed(base, &format!("{name}-fix"), &path)).chain(passes).collect::<Vec<_>>()
    };
    [project(10, "one"), project(20, "two")].concat()
}
