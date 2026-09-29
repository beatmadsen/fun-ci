//! How the table draws runs (design.md, The console): one stage per column in
//! lint, build, fast, slow order, a mark and a time in each, the outcome and
//! the age aligned on every row; the newest run of each branch carries its
//! state in the gutter, and what a newer run replaced, was cancelled or waits
//! recedes.

use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::grid::{Colour, Emulator, Grid};
use fun_ci_renderer::model::Board;
use fun_ci_renderer::table::{Frame, draw, palette};
use serde_json::{Value, json};

const NOW: i64 = 1_790_000_000;

fn stage(name: &str, status: &str, ms: u64) -> Value {
    json!({"stage": name, "status": status, "duration_ms": ms})
}

fn run(id: u64, branch: &str, status: &str, stages: &[Value]) -> Value {
    json!({"id": id, "sha": format!("{id}a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4c6d8e0"), "branch": branch,
           "project": "/src/app", "status": status, "updated_at": NOW - 360, "stages": stages})
}

fn passed(id: u64, branch: &str) -> Value {
    let stages = ["lint", "build", "fast", "slow"].map(|s| stage(s, "passed", 1_200));
    run(id, branch, "passed", &stages)
}

fn failed(id: u64, branch: &str) -> Value {
    run(id, branch, "failed", &[stage("lint", "passed", 300), stage("build", "passed", 900), stage("fast", "failed", 1_400)])
}

/// The table's lines for `runs` on a terminal `width` wide, one per screen row.
fn table(runs: &[Value], width: u16) -> Grid {
    table_with_cursor(runs, width, None)
}

fn table_with_cursor(runs: &[Value], width: u16, cursor: Option<usize>) -> Grid {
    let board: Board = serde_json::from_value(json!({"now": NOW, "cursor": cursor, "runs": runs})).unwrap();
    let frame = Frame { now_ms: NOW * 1000, play_ms: 0, spinner: '⠹', width, depth: Depth::TrueColour };
    let lines = draw(&board, frame).lines;
    let rows = u16::try_from(lines.len()).unwrap();
    let mut emulator = Emulator::new((width, rows));
    emulator.feed((width, rows), lines.join("\r\n").as_bytes());
    emulator.grid()
}

fn row_text(grid: &Grid, row: usize) -> String {
    grid.text().lines().nth(row).unwrap_or_default().to_string()
}

/// The column `word` starts at on screen row `row`.
fn column(grid: &Grid, row: usize, word: &str) -> usize {
    let text = row_text(grid, row);
    let at = text.find(word).unwrap_or_else(|| panic!("no {word:?} in {text:?}"));
    text[..at].chars().count()
}

fn fg_at(grid: &Grid, row: usize, word: &str) -> Colour {
    grid.cells[row][column(grid, row, word)].fg
}

fn attrs_at(grid: &Grid, row: usize, word: &str) -> Vec<&'static str> {
    grid.cells[row][column(grid, row, word)].attrs.clone()
}

fn rgb([r, g, b]: [u8; 3]) -> Colour {
    Colour::Rgb(r, g, b)
}

#[test]
fn the_first_line_names_the_stages_above_their_columns() {
    let grid = table(&[passed(1, "main")], 100);
    assert_eq!(column(&grid, 0, "fast"), column(&grid, 1, "✓") + 18);
}

#[test]
fn a_passed_stage_shows_a_tick_and_its_time_in_green() {
    let grid = table(&[passed(1, "main")], 100);
    assert_eq!(fg_at(&grid, 1, "✓ 1.2s"), rgb(palette::PASSED));
}

#[test]
fn a_failed_stage_shows_a_cross_and_its_time_in_bold_red() {
    let grid = table(&[failed(1, "main")], 100);
    assert_eq!((fg_at(&grid, 1, "✗ 1.4s"), attrs_at(&grid, 1, "✗ 1.4s")), (rgb(palette::FAILED), vec!["bold"]));
}

#[test]
fn a_timed_out_stage_shows_a_warning_triangle_and_its_time_in_bold_amber() {
    let grid = table(&[run(1, "main", "timeout", &[stage("fast", "timeout", 10_000)])], 100);
    assert_eq!((fg_at(&grid, 1, "▲ 10s"), attrs_at(&grid, 1, "▲ 10s")), (rgb(palette::TIMED_OUT), vec!["bold"]));
}

#[test]
fn each_running_stage_shows_the_spinner_and_its_own_time_in_cyan() {
    let fast = json!({"stage": "fast", "status": "running", "started_at": NOW - 9});
    let slow = json!({"stage": "slow", "status": "running", "started_at": NOW - 40});
    let grid = table(&[run(1, "main", "running", &[fast, slow])], 100);
    assert_eq!((fg_at(&grid, 1, "⠹ 9s"), row_text(&grid, 1).contains("⠹ 40s")), (rgb(palette::RUNNING), true));
}

#[test]
fn a_stage_not_reached_is_a_faint_dot() {
    let grid = table(&[failed(1, "main")], 100);
    assert_eq!(fg_at(&grid, 1, "·"), rgb(palette::FAINT));
}

#[test]
fn stages_sit_in_lint_build_fast_slow_order_whatever_order_they_arrive_in() {
    let stages = [stage("slow", "passed", 2_000), stage("fast", "failed", 1_000)];
    let grid = table(&[run(1, "main", "failed", &stages)], 100);
    assert!(column(&grid, 1, "✗ 1s") < column(&grid, 1, "✓ 2s"));
}

#[test]
fn a_stage_starts_in_the_same_column_on_every_row() {
    let grid = table(&[failed(2, "main"), failed(1, "feature/a-much-longer-name")], 100);
    assert_eq!(column(&grid, 1, "✗"), column(&grid, 2, "✗"));
}

#[test]
fn the_newest_failed_run_of_a_branch_says_failed_in_bold_red() {
    let grid = table(&[failed(1, "main")], 100);
    assert_eq!((fg_at(&grid, 1, "FAILED"), attrs_at(&grid, 1, "FAILED")), (rgb(palette::FAILED), vec!["bold"]));
}

#[test]
fn the_newest_passed_run_of_a_branch_says_passed_in_bold_green() {
    let grid = table(&[passed(1, "main")], 100);
    assert_eq!((fg_at(&grid, 1, "PASSED"), attrs_at(&grid, 1, "PASSED")), (rgb(palette::PASSED), vec!["bold"]));
}

#[test]
fn a_run_its_branch_has_a_newer_run_of_says_its_outcome_in_lower_case() {
    let grid = table(&[passed(2, "main"), failed(1, "main")], 100);
    assert!(row_text(&grid, 2).contains("failed"));
}

#[test]
fn a_run_its_branch_has_a_newer_run_of_is_dimmed() {
    let grid = table(&[passed(2, "main"), failed(1, "main")], 100);
    assert_eq!(fg_at(&grid, 2, "failed"), rgb(palette::dimmed(palette::FAILED)));
}

#[test]
fn a_cancelled_run_is_faint_throughout() {
    let grid = table(&[run(1, "main", "cancelled", &[stage("lint", "passed", 300)])], 100);
    assert_eq!([fg_at(&grid, 1, "0.3s"), fg_at(&grid, 1, "cancelled")], [rgb(palette::FAINT); 2]);
}

#[test]
fn a_scheduled_run_says_waiting_in_grey_brighter_than_a_cancelled_one() {
    let grid = table(&[run(1, "main", "pending", &[])], 100);
    assert_eq!(fg_at(&grid, 1, "waiting"), rgb(palette::SECONDARY));
}

#[test]
fn a_scheduled_run_s_stages_are_hollow_circles() {
    let grid = table(&[run(1, "main", "pending", &[])], 100);
    assert_eq!(row_text(&grid, 1).matches('◌').count(), 4);
}

fn conflicting(branch: &str) -> Value {
    let mut run = failed(1, branch);
    run["trunk"] = json!({"branch_state": "conflicts", "trunk": "main"});
    run
}

#[test]
fn a_branch_that_conflicts_with_the_trunk_says_so_in_magenta_after_its_name() {
    let grid = table(&[conflicting("feat/x")], 100);
    assert_eq!((fg_at(&grid, 1, "conflicts main"), column(&grid, 1, "conflicts main")), (rgb(palette::CONFLICT), column(&grid, 1, "feat/x") + 7));
}

#[test]
fn a_conflict_without_room_for_words_is_a_zigzag() {
    let grid = table(&[conflicting("feature/a-branch-name-long-enough-to-crowd-it")], 80);
    assert!(row_text(&grid, 1).contains("↯ main"), "{:?}", row_text(&grid, 1));
}

#[test]
fn a_branch_too_long_for_its_column_is_cut_with_an_ellipsis() {
    let grid = table(&[failed(1, &"a-very-long-branch-name-".repeat(6))], 80);
    assert!(row_text(&grid, 1).contains("…"));
}

#[test]
fn a_branch_too_long_for_its_column_leaves_the_outcome_on_the_row() {
    let grid = table(&[failed(1, &"a-very-long-branch-name-".repeat(6))], 80);
    assert!(row_text(&grid, 1).contains("FAILED"));
}

#[test]
fn the_newest_run_of_a_branch_has_a_bar_in_its_state_s_colour() {
    let grid = table(&[failed(1, "main")], 100);
    assert_eq!((grid.cells[1][0].text.as_str(), grid.cells[1][0].fg), ("▌", rgb(palette::FAILED)));
}

#[test]
fn a_run_its_branch_has_a_newer_run_of_has_no_bar() {
    let grid = table(&[passed(2, "main"), failed(1, "main")], 100);
    assert_eq!(grid.cells[2][0].text.trim(), "");
}

#[test]
fn the_newest_failed_run_of_a_branch_is_tinted() {
    let grid = table(&[failed(1, "main")], 100);
    assert_eq!(grid.cells[1][column(&grid, 1, "main")].bg, rgb(palette::FAILED_TINT));
}

#[test]
fn the_project_is_named_in_grey() {
    let mut other = passed(2, "main");
    other["project"] = "/src/other".into();
    let grid = table(&[other, passed(1, "main")], 100);
    assert_eq!(fg_at(&grid, 1, "other"), rgb(palette::SECONDARY));
}

#[test]
fn the_project_is_left_out_when_every_run_shares_it() {
    let grid = table(&[passed(2, "main"), passed(1, "dev")], 100);
    assert!(!row_text(&grid, 1).contains("app"));
}

#[test]
fn a_narrow_terminal_shows_each_stage_s_mark_without_its_time() {
    let grid = table(&[passed(1, "main")], 60);
    assert!(!row_text(&grid, 1).contains("1.2s"));
}

#[test]
fn the_age_is_short_and_ends_the_row() {
    let grid = table(&[passed(1, "main")], 100);
    assert!(row_text(&grid, 1).trim_end().ends_with(" 6m"));
}

#[test]
fn a_branch_longer_than_its_column_s_widest_does_not_push_the_stages_right() {
    let long = table(&[failed(2, &"b".repeat(80)), failed(1, "main")], 120);
    let moderate = table(&[failed(2, &"b".repeat(40)), failed(1, "main")], 120);
    assert_eq!(column(&long, 2, "✗"), column(&moderate, 2, "✗"));
}

#[test]
fn the_age_ends_a_column_short_of_the_edge() {
    let grid = table(&[failed(1, &"b".repeat(80))], 80);
    assert_eq!(row_text(&grid, 1).trim_end().chars().count(), 79);
}

fn running(id: u64) -> Value {
    run(id, "main", "running", &[json!({"stage": "fast", "status": "running", "started_at": NOW - 9})])
}

#[test]
fn a_running_run_has_no_band_since_running_is_no_trouble() {
    let grid = table(&[running(1)], 100);
    assert_eq!(grid.cells[1][column(&grid, 1, "main")].bg, Colour::Default);
}

#[test]
fn a_running_stage_is_bold() {
    let grid = table(&[running(1)], 100);
    assert_eq!(attrs_at(&grid, 1, "⠹ 9s"), vec!["bold"]);
}

#[test]
fn the_cursor_mark_is_bold_white() {
    let grid = table_with_cursor(&[passed(1, "main")], 100, Some(0));
    let mark = &grid.cells[1][1];
    assert_eq!((mark.text.as_str(), mark.fg, mark.attrs.clone()), ("❯", rgb(palette::CURSOR), vec!["bold"]));
}

#[test]
fn the_branch_under_the_cursor_is_bold() {
    let grid = table_with_cursor(&[passed(1, "main")], 100, Some(0));
    assert_eq!(attrs_at(&grid, 1, "main"), vec!["bold"]);
}

/// The sum of the channels of `row`'s background under its branch.
fn paper_brightness(grid: &Grid, row: usize) -> u16 {
    match grid.cells[row][column(grid, row, "main")].bg {
        Colour::Rgb(r, g, b) => u16::from(r) + u16::from(g) + u16::from(b),
        other => panic!("no paper: {other:?}"),
    }
}

#[test]
fn a_failed_row_under_the_cursor_is_clearly_lighter_than_one_that_is_not() {
    let grid = table_with_cursor(&[failed(2, "main"), failed(1, "main")], 100, Some(0));
    let cursor_row = table_with_cursor(&[failed(1, "main")], 100, Some(0));
    let plain_row = table(&[failed(1, "main")], 100);
    assert!(paper_brightness(&cursor_row, 1) >= paper_brightness(&plain_row, 1) + 60, "{grid:?}");
}

#[test]
fn a_narrow_terminal_leaves_out_the_sha_before_the_project() {
    let mut other = passed(2, "feature/a-long-branch");
    other["project"] = "/src/other".into();
    let grid = table(&[other, passed(1, "main")], 80);
    assert_eq!([row_text(&grid, 1).contains("other"), row_text(&grid, 1).contains("2a3f7c0")], [true, false]);
}

#[test]
fn a_branch_cut_to_fit_keeps_its_conflict_marker_whole_and_apart() {
    let grid = table(&[conflicting(&"b".repeat(80))], 80);
    assert!(row_text(&grid, 1).contains("… ↯ main  "), "{:?}", row_text(&grid, 1));
}

fn two_projects_with_long_names(width: u16) -> Grid {
    let mut first = passed(2, "refactor/extract-the-evidence-collector");
    first["project"] = "/src/strings-kata-and-more".into();
    table(&[first, passed(1, "main")], width)
}

/// How many columns of the first row `text` fills, starting where it starts.
fn visible(grid: &Grid, text: &str) -> usize {
    let row = row_text(grid, 1);
    let prefix: String = text.chars().take(4).collect();
    row[row.find(&prefix).unwrap()..].split("  ").next().unwrap().chars().count()
}

#[test]
fn a_narrow_terminal_keeps_more_of_the_branch_than_of_the_project() {
    let grid = two_projects_with_long_names(60);
    assert!(visible(&grid, "refactor") >= 12, "{:?}", row_text(&grid, 1));
}

#[test]
fn a_wide_terminal_shows_a_long_branch_in_full() {
    let grid = table(&[passed(1, "refactor/extract-the-evidence-collector-from-stage-end")], 200);
    assert!(row_text(&grid, 1).contains("refactor/extract-the-evidence-collector-from-stage-end"));
}

#[test]
fn the_cursor_keeps_a_failed_row_red() {
    let grid = table_with_cursor(&[failed(1, "main")], 100, Some(0));
    let Colour::Rgb(r, g, b) = grid.cells[1][column(&grid, 1, "main")].bg else { panic!("no paper") };
    assert!(r > g.max(b) + 30, "{:?}", (r, g, b));
}

#[test]
fn the_cursor_mark_is_set_apart_from_the_branch() {
    let grid = table_with_cursor(&[passed(1, "main")], 60, Some(0));
    assert_eq!(grid.cells[1][2].text.trim(), "");
}

#[test]
fn an_eighty_column_terminal_shortens_the_project_before_it_drops_the_stages_times() {
    let grid = two_projects_with_long_names(80);
    assert!(row_text(&grid, 1).contains("1.2s"), "{:?}", row_text(&grid, 1));
}

#[test]
fn a_band_ends_where_the_table_ends() {
    let grid = table(&[failed(1, "main")], 200);
    let end = row_text(&grid, 1).trim_end().chars().count();
    assert_eq!(grid.cells[1][end + 2].bg, Colour::Default);
}

#[test]
fn the_sha_and_age_are_quiet_rather_than_faint() {
    let grid = table(&[passed(1, "main")], 100);
    assert_eq!([fg_at(&grid, 1, "1a3f7c0"), fg_at(&grid, 1, "6m")], [rgb(palette::QUIET); 2]);
}

#[test]
fn the_sha_and_age_on_a_band_are_grey_enough_to_read() {
    let grid = table(&[failed(1, "main")], 100);
    assert_eq!([fg_at(&grid, 1, "1a3f7c0"), fg_at(&grid, 1, "6m")], [rgb(palette::SECONDARY); 2]);
}


#[test]
fn a_narrow_board_of_several_projects_shows_each_project_s_initial() {
    let grid = two_projects_with_long_names(60);
    assert!(row_text(&grid, 1).contains("  s  "), "{:?}", row_text(&grid, 1));
}

fn folded(count: u64) -> Value {
    let mut cancelled = run(1, "detached", "cancelled", &[stage("lint", "passed", 200), stage("build", "passed", 200)]);
    cancelled["folded"] = count.into();
    cancelled
}

#[test]
fn a_folded_row_says_how_many_cancelled_runs_it_stands_for() {
    let grid = table(&[folded(25)], 100);
    assert!(row_text(&grid, 1).contains("detached ×25"), "{:?}", row_text(&grid, 1));
}

#[test]
fn a_folded_row_shows_no_stages() {
    let grid = table(&[folded(25)], 100);
    assert!(!row_text(&grid, 1).contains("0.2s"), "{:?}", row_text(&grid, 1));
}

#[test]
fn a_replaced_run_s_branch_is_brighter_than_a_cancelled_one_s() {
    let grid = table(&[passed(3, "main"), passed(2, "main"), run(1, "dev", "cancelled", &[])], 100);
    let brightness = |row: usize, word: &str| match fg_at(&grid, row, word) {
        Colour::Rgb(r, g, b) => u16::from(r) + u16::from(g) + u16::from(b),
        other => panic!("{other:?}"),
    };
    assert!(brightness(2, "main") > brightness(3, "dev"));
}

#[test]
fn a_waiting_run_leaves_its_branch_s_last_result_in_charge() {
    let grid = table(&[run(2, "main", "pending", &[]), failed(1, "main")], 100);
    assert_eq!((grid.cells[2][0].text.as_str(), fg_at(&grid, 2, "FAILED")), ("▌", rgb(palette::FAILED)));
}

#[test]
fn a_waiting_run_has_no_bar_of_its_own() {
    let grid = table(&[run(2, "main", "pending", &[]), failed(1, "main")], 100);
    assert_eq!(grid.cells[1][0].text.trim(), "");
}

#[test]
fn a_replaced_run_s_sha_is_no_brighter_than_its_branch() {
    let grid = table(&[passed(2, "main"), passed(1, "main")], 100);
    assert_eq!(fg_at(&grid, 2, "1a3f7c0"), fg_at(&grid, 2, "main"));
}
