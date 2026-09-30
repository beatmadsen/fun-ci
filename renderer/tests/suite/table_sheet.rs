//! The table's lines drawn one under another, and the lead's block behind
//! its own (design.md, The console): a card of deep paper from the margin to
//! two past the age, between a top edge of lower half blocks and a bottom
//! edge of upper ones in the paper's colour, its corners rounded with
//! quadrants, and whatever is behind it showing past its edges.

use crate::support::paint::{COLUMNS, WIDTH, failed, passed, rgb};
use crate::support::shown::{blank, shown};
use fun_ci_renderer::grid::{Colour, Grid};
use fun_ci_renderer::table::line::placed;
use fun_ci_renderer::table::night::{self, ink};
use fun_ci_renderer::table::sheet::{Paper, Sheet};
use fun_ci_renderer::table::stack::Piece;
use ratatui::text::Line;
use ratatui::widgets::Widget;

const GREY: [u8; 3] = [200, 200, 200];

fn word(column: usize, text: &str) -> Line<'static> {
    placed(vec![(column, text.to_string(), ink(GREY))])
}

fn on_sheet(lines: &[Line<'static>], paper: Option<Paper>) -> Grid {
    let mut buffer = blank(WIDTH, 4);
    Sheet { lines, paper }.render(buffer.area, &mut buffer);
    shown(&buffer)
}

fn block(pieces: &[Piece]) -> Option<Paper> {
    Paper::over(pieces, 1, COLUMNS, night::WINE)
}

fn row(grid: &Grid, y: usize) -> String {
    grid.text().lines().nth(y).unwrap_or_default().to_string()
}

#[test]
fn the_sheet_draws_each_line_under_the_one_before() {
    let grid = on_sheet(&[word(0, "one"), word(2, "two")], None);

    assert_eq!((row(&grid, 0).trim_end(), row(&grid, 1).trim_end()), ("one", "  two"));
}

#[test]
fn the_lead_s_row_is_on_the_block_s_paper_from_the_margin_to_two_past_its_age() {
    let run = failed();
    let grid = on_sheet(&[Line::default(), word(14, "feat")], block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false)]));
    let paper = [COLUMNS.margin - 1, COLUMNS.margin, COLUMNS.age_end + 1, COLUMNS.age_end + 2].map(|x| grid.cells[1][x].bg);

    assert_eq!(paper, [Colour::Default, rgb(night::WINE), rgb(night::WINE), Colour::Default]);
}

#[test]
fn text_on_the_paper_keeps_the_paper_behind_it() {
    let run = failed();
    let grid = on_sheet(&[Line::default(), word(14, "feat")], block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false)]));

    assert_eq!(grid.cells[1][14].bg, rgb(night::WINE));
}

#[test]
fn the_block_s_top_edge_is_a_row_of_lower_half_blocks_in_its_colour() {
    let run = failed();
    let grid = on_sheet(&[], block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false)]));

    assert_eq!((grid.cells[0][COLUMNS.margin + 1].text.as_str(), grid.cells[0][COLUMNS.margin + 1].fg), ("▄", rgb(night::WINE)));
}

#[test]
fn the_block_s_bottom_edge_is_a_row_of_upper_half_blocks_in_its_colour() {
    let run = failed();
    let grid = on_sheet(&[], block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false)]));

    assert_eq!((grid.cells[2][COLUMNS.margin + 1].text.as_str(), grid.cells[2][COLUMNS.margin + 1].fg), ("▀", rgb(night::WINE)));
}

#[test]
fn the_block_s_edges_leave_what_is_behind_them_showing() {
    let run = failed();
    let grid = on_sheet(&[], block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false)]));

    assert_eq!((grid.cells[0][COLUMNS.margin].bg, grid.cells[2][COLUMNS.margin].bg), (Colour::Default, Colour::Default));
}

#[test]
fn the_block_s_edges_span_the_block() {
    let run = failed();
    let grid = on_sheet(&[], block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false)]));

    assert_eq!(row(&grid, 2).trim().chars().count(), COLUMNS.age_end + 2 - COLUMNS.margin);
}

#[test]
fn a_line_on_the_paper_is_cut_where_the_paper_ends() {
    let run = failed();
    let grid = on_sheet(&[Line::default(), word(COLUMNS.age_end, "overflowing")], block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false)]));

    assert_eq!(row(&grid, 1).trim_end().chars().count(), COLUMNS.age_end + 2);
}

#[test]
fn a_line_below_the_paper_is_not_cut_where_the_paper_ends() {
    let run = failed();
    let lines = [Line::default(), Line::default(), Line::default(), word(COLUMNS.age_end, "overflowing")];
    let grid = on_sheet(&lines, block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false), Piece::Blank]));

    assert_eq!(row(&grid, 3).trim_end().chars().count(), COLUMNS.age_end + 11);
}

#[test]
fn a_block_whose_top_edge_is_off_the_screen_has_only_its_bottom_edge() {
    let run = failed();
    let grid = on_sheet(&[], block(&[Piece::More(3, false), Piece::Row(&run), Piece::Edge(false)]));

    assert_eq!((grid.cells[0][COLUMNS.margin].text.as_str(), grid.cells[1][COLUMNS.margin].bg), ("", rgb(night::WINE)));
}

#[test]
fn the_block_takes_in_the_lead_s_conflict() {
    let run = failed();
    let grid = on_sheet(&[], block(&[Piece::Edge(true), Piece::Row(&run), Piece::Conflict(&run), Piece::Edge(false)]));

    assert_eq!((grid.cells[2][COLUMNS.margin].bg, grid.cells[3][COLUMNS.margin + 1].text.as_str()), (rgb(night::WINE), "▀"));
}

#[test]
fn there_is_no_block_when_the_lead_s_row_is_not_among_the_pieces() {
    let other = passed();

    assert_eq!(block(&[Piece::Row(&other), Piece::Blank]), None);
}

#[test]
fn a_sheet_drawn_further_in_moves_its_block_with_it() {
    let run = failed();
    let mut buffer = blank(WIDTH, 4);
    let paper = block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false)]);
    Sheet { lines: &[], paper }.render(ratatui::layout::Rect::new(3, 0, WIDTH - 3, 4), &mut buffer);

    assert_eq!(shown(&buffer).cells[0][COLUMNS.age_end + 2 + 1].text, "▄");
}

#[test]
fn the_block_s_corners_are_rounded_with_quadrants() {
    let run = failed();
    let grid = on_sheet(&[], block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false)]));
    let (left, right) = (COLUMNS.margin, COLUMNS.age_end + 1);

    assert_eq!([&grid.cells[0][left].text, &grid.cells[0][right].text, &grid.cells[2][left].text, &grid.cells[2][right].text], ["▗", "▖", "▝", "▘"]);
}

#[test]
fn the_block_s_sides_are_paper_too() {
    let run = failed();
    let grid = on_sheet(&[], block(&[Piece::Edge(true), Piece::Row(&run), Piece::Edge(false)]));

    assert_eq!((grid.cells[1][COLUMNS.margin].bg, grid.cells[1][COLUMNS.age_end + 1].bg), (rgb(night::WINE), rgb(night::WINE)));
}
