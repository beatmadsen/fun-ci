//! Lines of the table painted one at a time on a 120-column screen, and
//! what they show, for the painting tests.

use fun_ci_renderer::grid::{Colour, Grid};
use ratatui::widgets::Widget;

use super::shown::{blank, shown};
use fun_ci_renderer::model::{Run, StaleTrunk};
use fun_ci_renderer::table::Frame;
use fun_ci_renderer::table::columns::Columns;
use fun_ci_renderer::table::line::Line;
use fun_ci_renderer::table::night;
use fun_ci_renderer::table::paint::{Paint, paint};
use fun_ci_renderer::table::stack::Piece;
use serde_json::{Value, json};

pub const NOW: i64 = 1_790_000_000;
pub const WIDTH: u16 = 120;

pub fn done(stage: &str, status: &str, ms: u64) -> Value {
    json!({"stage": stage, "status": status, "duration_ms": ms})
}

pub fn run(id: u64, branch: &str, status: &str, stages: &[Value]) -> Run {
    serde_json::from_value(json!({"id": id, "sha": "0", "branch": branch, "project": "/src/strings-kata",
                                  "status": status, "updated_at": NOW - 360, "stages": stages}))
    .unwrap()
}

pub fn failed() -> Run {
    run(1, "feat", "failed", &[done("lint", "passed", 300), done("build", "passed", 900), done("fast", "failed", 1_400)])
}

pub fn passed() -> Run {
    run(2, "main", "passed", &["lint", "build", "fast", "slow"].map(|s| done(s, "passed", 1_200)))
}

pub const COLUMNS: Columns = Columns { margin: 10, label: 12, branch: 14, name: 17, gap: 4, strip: 35, words: 46, age_end: 81 };

pub fn frame() -> Frame {
    Frame { now_ms: NOW * 1000, play_ms: 0, spinner: '⠹', width: WIDTH }
}

pub fn drawn(piece: &Piece, lead: Option<u64>, stale: &[StaleTrunk]) -> Grid {
    on_screen(&paint(piece, &Paint { columns: COLUMNS, frame: frame(), lead, stale, paper: night::WINE, tags: None }))
}

/// `line` drawn across a screen `WIDTH` wide.
pub fn on_screen(line: &Line) -> Grid {
    let mut buffer = blank(WIDTH, 1);
    line.render(buffer.area, &mut buffer);
    shown(&buffer)
}

pub fn text(grid: &Grid) -> String {
    grid.text().lines().next().unwrap_or_default().to_string()
}

pub fn at(grid: &Grid, column: usize) -> String {
    text(grid).chars().skip(column).collect::<String>()
}

pub fn rgb([r, g, b]: [u8; 3]) -> Colour {
    Colour::Rgb(r, g, b)
}

pub fn fg(grid: &Grid, column: usize) -> Colour {
    grid.cells[0][column].fg
}

pub fn bg(grid: &Grid, column: usize) -> Colour {
    grid.cells[0][column].bg
}
