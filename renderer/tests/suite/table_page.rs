//! What goes below the header down to the footer (design.md, The console):
//! the table, blank lines, and when the table had to go flat, the stale
//! trunks' note with a blank line between it and the footer.

use crate::support::paint::{COLUMNS, frame};
use fun_ci_renderer::model::Board;
use fun_ci_renderer::table::Drawn;
use fun_ci_renderer::table::line::placed;
use fun_ci_renderer::table::night::ink;
use fun_ci_renderer::table::page::page;
use ratatui::text::Line;
use serde_json::json;

fn busy_board() -> Board {
    let run = json!({"id": 1, "sha": "0", "branch": "b", "status": "failed", "updated_at": 0, "stages": []});
    serde_json::from_value(json!({"now": 0, "runs": [run]})).unwrap()
}

fn row() -> Line<'static> {
    placed(vec![(0, "row".to_string(), ink([200, 200, 200]))])
}

fn drawn(table: usize, note: Option<&str>) -> Drawn {
    Drawn { lines: vec![row(); table], rows: Vec::new(), columns: COLUMNS, unshown: 0, note: note.map(String::from), paper: None, leaders: None }
}

/// Each line of the page, as the words it says.
fn laid_out(table: usize, note: Option<&str>) -> Vec<String> {
    page(&busy_board(), &drawn(table, note), frame(), 10).iter().map(|line| line.to_string().trim_end().to_string()).collect()
}

#[test]
fn the_page_is_as_many_lines_as_it_is_given() {
    assert_eq!(laid_out(3, None).len(), 10);
}

#[test]
fn the_table_comes_first_and_blank_lines_after_it() {
    let lines = laid_out(3, None);

    assert_eq!((lines[2].as_str(), lines[3].as_str(), lines[9].as_str()), ("row", "", ""));
}

#[test]
fn the_note_sits_above_one_blank_line() {
    let lines = laid_out(3, Some("two: trunk last fetched 2h ago"));

    assert_eq!((lines[8].contains("trunk last fetched"), lines[9].as_str(), lines[7].as_str()), (true, "", ""));
}

#[test]
fn with_no_line_to_spare_the_note_is_the_last() {
    let lines = laid_out(9, Some("two: trunk last fetched 2h ago"));

    assert!(lines[9].contains("trunk last fetched"), "{lines:?}");
}
