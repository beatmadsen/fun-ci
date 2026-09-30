//! The night the table sits in (design.md, The console): dusky violet just
//! under the header, deepening over the first rows to the night below.

use crate::support::shown::{blank, shown};
use fun_ci_renderer::grid::Colour;
use fun_ci_renderer::table::night;
use fun_ci_renderer::table::sky::{Sky, shade};
use ratatui::widgets::Widget;

fn rgb([r, g, b]: [u8; 3]) -> Colour {
    Colour::Rgb(r, g, b)
}

#[test]
fn the_sky_starts_at_dusk_under_the_header() {
    assert_eq!(shade(0), night::DUSK);
}

#[test]
fn the_sky_is_night_eight_rows_down() {
    assert_eq!(shade(8), night::NIGHT);
}

#[test]
fn the_sky_stays_night_below_that() {
    assert_eq!(shade(30), night::NIGHT);
}

#[test]
fn the_sky_deepens_row_by_row() {
    let red = |row: usize| shade(row)[0];

    assert!(red(0) > red(1) && red(1) > red(3) && red(3) > red(6), "{:?}", (0..9).map(shade).collect::<Vec<_>>());
}

#[test]
fn the_sky_colours_every_cell_of_its_row() {
    let mut buffer = blank(10, 3);
    Sky.render(buffer.area, &mut buffer);

    assert_eq!((shown(&buffer).cells[1][0].bg, shown(&buffer).cells[1][9].bg), (rgb(shade(1)), rgb(shade(1))));
}
