//! Each row of the table as it is drawn: one phrase, name, marks, words and
//! age; pale once passed, quiet once cancelled; the lead's row on the block's
//! paper between the block's edges.

use crate::support::paint::{at, bg, drawn, failed, fg, passed, rgb, run, text};
use fun_ci_renderer::grid::Colour;
use fun_ci_renderer::table::night;
use fun_ci_renderer::table::stack::Piece;

#[test]
fn a_row_names_its_branch_where_names_start() {
    assert!(at(&drawn(&Piece::Row(&failed()), None, &[]), 14).starts_with("feat "));
}

#[test]
fn a_row_s_marks_start_at_the_strip() {
    assert!(at(&drawn(&Piece::Row(&failed()), None, &[]), 35).starts_with("✓ ✓ ◆ ·"));
}

#[test]
fn a_row_says_what_happened_after_its_marks() {
    assert!(at(&drawn(&Piece::Row(&failed()), None, &[]), 46).starts_with("failed in fast · 1.4s "));
}

#[test]
fn a_row_ends_with_its_age() {
    assert!(text(&drawn(&Piece::Row(&failed()), None, &[])).trim_end().ends_with(" 6m"));
}

#[test]
fn a_passed_row_is_pale() {
    assert_eq!(fg(&drawn(&Piece::Row(&passed()), None, &[]), 14), rgb(night::pale(night::BRANCH)));
}

#[test]
fn the_lead_s_name_is_bold_in_the_cursor_s_colour() {
    let grid = drawn(&Piece::Row(&passed()), Some(2), &[]);

    assert_eq!((fg(&grid, 14), grid.cells[0][14].attrs.clone()), (rgb(night::CURSOR), vec!["bold"]));
}

#[test]
fn the_lead_s_row_is_not_pale() {
    assert_eq!(fg(&drawn(&Piece::Row(&passed()), Some(2), &[]), 35), rgb(night::PASSED));
}

#[test]
fn the_lead_s_row_is_on_the_block_s_paper_from_the_margin_to_two_past_its_age() {
    let grid = drawn(&Piece::Row(&failed()), Some(1), &[]);

    assert_eq!([9, 10, 82, 83].map(|column| bg(&grid, column)), [Colour::Default, rgb(night::WINE), rgb(night::WINE), Colour::Default]);
}

#[test]
fn the_block_s_top_edge_is_a_row_of_lower_half_blocks_in_its_colour() {
    let grid = drawn(&Piece::Edge(true), Some(1), &[]);

    assert_eq!((at(&grid, 10).chars().next(), fg(&grid, 10)), (Some('▄'), rgb(night::WINE)));
}

#[test]
fn the_block_s_edges_span_the_block() {
    assert_eq!(text(&drawn(&Piece::Edge(false), Some(1), &[])).trim().chars().count(), 83 - 10);
}

#[test]
fn a_cancelled_row_s_name_is_quiet() {
    let run = run(5, "detached", "cancelled", &[]);

    assert_eq!(fg(&drawn(&Piece::Row(&run), None, &[]), 14), rgb(night::QUIET));
}
