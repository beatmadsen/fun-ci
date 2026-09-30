//! A line of the table placed as ratatui spans and drawn into the screen's
//! buffer: each part's text where it starts, in its colour, bold or in
//! italics, and cut where the screen ends, so it never wraps.

use crate::support::shown::{blank, shown};
use fun_ci_renderer::grid::{Colour, Grid};
use fun_ci_renderer::table::line::{Part, placed};
use fun_ci_renderer::table::night::ink;
use ratatui::widgets::Widget;

const GREY: [u8; 3] = [200, 200, 200];

fn part(column: usize, text: &str) -> Part {
    (column, text.to_string(), ink(GREY))
}

fn drawn(parts: Vec<Part>, width: u16) -> Grid {
    let mut buffer = blank(width, 1);
    placed(parts).render(buffer.area, &mut buffer);
    shown(&buffer)
}

fn row(grid: &Grid) -> String {
    grid.text().lines().next().unwrap_or_default().trim_end().to_string()
}

#[test]
fn a_part_is_drawn_in_its_colour() {
    assert_eq!(drawn(vec![part(0, "word")], 20).cells[0][0].fg, Colour::Rgb(200, 200, 200));
}

#[test]
fn an_italic_part_is_drawn_in_italics() {
    assert_eq!(drawn(vec![(0, "note".into(), ink(GREY).italic())], 20).cells[0][0].attrs, vec!["italic"]);
}

#[test]
fn a_plain_part_after_an_italic_one_is_upright() {
    assert!(drawn(vec![(0, "note".into(), ink(GREY).italic()), part(5, "word")], 20).cells[0][5].attrs.is_empty());
}

#[test]
fn a_part_starts_at_its_column() {
    assert_eq!(row(&drawn(vec![part(3, "word")], 20)), "   word");
}

#[test]
fn a_part_running_past_the_screen_is_cut_at_its_edge() {
    assert_eq!(row(&drawn(vec![part(6, "overflowing")], 10)), "      over");
}

#[test]
fn a_part_starting_inside_the_one_before_follows_it() {
    assert_eq!(row(&drawn(vec![part(0, "longer"), part(3, "next")], 20)), "longernext");
}

#[test]
fn parts_are_placed_by_column_whatever_order_they_come_in() {
    assert_eq!(row(&drawn(vec![part(8, "second"), part(1, "first")], 20)), " first  second");
}

#[test]
fn a_wide_character_takes_two_columns_before_the_next_part() {
    assert_eq!(drawn(vec![part(0, "漢字"), part(5, "x")], 20).cells[0][5].text, "x");
}

#[test]
fn a_line_with_no_parts_is_blank() {
    assert_eq!(placed(Vec::new()).width(), 0);
}

#[test]
fn a_part_both_bold_and_italic_is_drawn_both() {
    assert_eq!(drawn(vec![(0, "note".into(), ink(GREY).bold().italic())], 20).cells[0][0].attrs, vec!["bold", "italic"]);
}

#[test]
fn a_line_drawn_further_in_starts_its_parts_from_there() {
    let mut buffer = blank(20, 1);
    placed(vec![part(0, "longer"), part(3, "next")]).render(ratatui::layout::Rect::new(4, 0, 16, 1), &mut buffer);

    assert_eq!(row(&shown(&buffer)), "    longernext");
}
