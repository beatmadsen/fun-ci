//! A branch named in characters two columns wide, as Chinese, Japanese and
//! Korean are, takes its row's room by the columns it fills on screen, not by
//! how many characters it has: its marks line up with every other row's, and
//! a name too long for its room is cut to it.

use fun_ci_renderer::grid::Grid;
use serde_json::{Value, json};

use crate::support::boards::{board, frames, run};
use fun_ci_renderer::headless::emulate;

/// A passed run on `branch`.
fn named(id: u64, branch: &str) -> Value {
    let mut run = run(id, "passed", &[("lint", "passed"), ("build", "passed"), ("fast", "passed"), ("slow", "passed")]);
    run["branch"] = json!(branch);
    run
}

/// The screen once a board of `branches`, the cursor on the first, is drawn `width` columns wide.
fn screen(branches: &[&str], width: u16) -> Grid {
    let runs: Vec<Value> = (1..).zip(branches).map(|(id, branch)| named(id, branch)).collect();
    let mut board: Value = serde_json::from_str(&board(&runs)).unwrap();
    board["cursor"] = json!(0);
    let resize = json!({"t": "resize", "cols": width, "rows": 24}).to_string();
    emulate(&frames(&[resize, board.to_string(), r#"{"t":"tick","ms":0}"#.to_string()])).pop().unwrap()
}

/// The screen column of the first mark on each row that has one.
fn first_marks(grid: &Grid) -> Vec<usize> {
    grid.cells.iter().filter_map(|row| row.iter().position(|cell| cell.text == "✓")).collect()
}

#[test]
fn a_wide_name_s_marks_line_up_with_the_other_rows() {
    let marks = first_marks(&screen(&["機能検索機能検索", "main"], 60));

    assert_eq!(marks.len(), 2);
    assert_eq!(marks[0], marks[1], "{marks:?}");
}

#[test]
fn a_wide_name_too_long_for_its_room_is_cut_to_it() {
    let marks = first_marks(&screen(&["新しい検索機能の実装とテストの追加と改善", "main"], 60));

    assert_eq!(marks.len(), 2);
    assert_eq!(marks[0], marks[1], "{marks:?}");
}

