//! A line of the table drawn into the screen's buffer: each part's text where
//! it starts, in its colour, bold or in italics; on the block's paper when it
//! has one; and cut where the screen or the paper ends, so it never wraps.

use crate::support::shown::{blank, shown};
use fun_ci_renderer::grid::{Colour, Grid};
use fun_ci_renderer::table::line::{Line, Paper, Style};
use ratatui::widgets::Widget;

const GREY: [u8; 3] = [200, 200, 200];
const WINE: [u8; 3] = [46, 20, 26];

fn drawn(line: &Line, width: u16) -> Grid {
    let mut buffer = blank(width, 1);
    line.render(buffer.area, &mut buffer);
    shown(&buffer)
}

fn row(grid: &Grid) -> String {
    grid.text().lines().next().unwrap_or_default().trim_end().to_string()
}

#[test]
fn an_italic_part_is_drawn_in_italics() {
    let mut line = Line::default();
    line.put(0, "note", Style::italic(GREY));

    assert_eq!(drawn(&line, 20).cells[0][0].attrs, vec!["italic"]);
}

#[test]
fn a_plain_part_after_an_italic_one_is_upright() {
    let mut line = Line::default();
    line.put(0, "note", Style::italic(GREY));
    line.put(5, "word", Style::plain(GREY));

    assert!(drawn(&line, 20).cells[0][5].attrs.is_empty());
}

#[test]
fn a_part_starts_at_its_column() {
    let mut line = Line::default();
    line.put(3, "word", Style::plain(GREY));

    assert_eq!(row(&drawn(&line, 20)), "   word");
}

#[test]
fn a_part_running_past_the_screen_is_cut_at_its_edge() {
    let mut line = Line::default();
    line.put(6, "overflowing", Style::plain(GREY));

    assert_eq!(row(&drawn(&line, 10)), "      over");
}

#[test]
fn a_part_starting_inside_the_one_before_follows_it() {
    let mut line = Line::default();
    line.put(0, "longer", Style::plain(GREY));
    line.put(3, "next", Style::plain(GREY));

    assert_eq!(row(&drawn(&line, 20)), "longernext");
}

#[test]
fn the_paper_colours_the_line_from_its_start_to_its_end() {
    let line = Line::on(Paper { start: 2, end: 5, colour: WINE });
    let grid = drawn(&line, 10);

    assert_eq!([1, 2, 4, 5].map(|x| grid.cells[0][x].bg), [Colour::Default, Colour::Rgb(46, 20, 26), Colour::Rgb(46, 20, 26), Colour::Default]);
}

#[test]
fn text_on_the_paper_keeps_the_paper_behind_it() {
    let mut line = Line::on(Paper { start: 0, end: 8, colour: WINE });
    line.put(1, "word", Style::bold(GREY));

    assert_eq!(drawn(&line, 10).cells[0][1].bg, Colour::Rgb(46, 20, 26));
}

#[test]
fn a_part_running_past_the_paper_is_cut_where_the_paper_ends() {
    let mut line = Line::on(Paper { start: 0, end: 6, colour: WINE });
    line.put(2, "overflowing", Style::plain(GREY));

    assert_eq!(row(&drawn(&line, 20)), "  over");
}

#[test]
fn a_line_with_no_parts_is_blank() {
    assert!(Line::default().is_blank());
}

#[test]
fn a_line_with_a_part_is_not_blank() {
    let mut line = Line::default();
    line.put(0, "x", Style::plain(GREY));

    assert!(!line.is_blank());
}

#[test]
fn a_part_both_bold_and_italic_is_drawn_both() {
    let mut line = Line::default();
    line.put(0, "note", Style { fg: GREY, bold: true, italic: true });

    assert_eq!(drawn(&line, 20).cells[0][0].attrs, vec!["bold", "italic"]);
}

#[test]
fn a_line_drawn_further_in_starts_its_parts_from_there() {
    let mut line = Line::default();
    line.put(0, "longer", Style::plain(GREY));
    line.put(3, "next", Style::plain(GREY));
    let mut buffer = blank(20, 1);
    line.render(ratatui::layout::Rect::new(4, 0, 16, 1), &mut buffer);

    assert_eq!(row(&shown(&buffer)), "    longernext");
}
