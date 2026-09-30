//! The bytes a frame is written as: ratatui hands the backend the cells that
//! changed, and it writes each where it belongs, in the colours the terminal
//! has, with only the escapes a change of style needs.

use fun_ci_renderer::grid::{Colour, Emulator, Grid};
use fun_ci_renderer::output::backend::AnsiBackend;
use fun_ci_renderer::output::depth::Depth;
use ratatui::backend::{Backend, ClearType};
use ratatui::buffer::Cell;
use ratatui::style::{Color, Modifier};

fn cell(symbol: &str, fg: Color, modifier: Modifier) -> Cell {
    let mut cell = Cell::default();
    cell.set_symbol(symbol);
    cell.set_style(ratatui::style::Style::default().fg(fg).add_modifier(modifier));
    cell
}

/// The screen a terminal 10 columns wide and 3 rows high shows after `cells`.
fn drawn(depth: Depth, cells: &[(u16, u16, Cell)]) -> Grid {
    let mut backend = AnsiBackend::new((10, 3), depth);
    backend.draw(cells.iter().map(|(x, y, cell)| (*x, *y, cell))).unwrap();
    let mut emulator = Emulator::new((10, 3));
    emulator.feed((10, 3), &backend.take());
    emulator.grid()
}

#[test]
fn a_cell_is_written_where_it_belongs() {
    let grid = drawn(Depth::TrueColour, &[(3, 1, cell("x", Color::Reset, Modifier::empty()))]);

    assert_eq!(grid.cells[1][3].text, "x");
}

#[test]
fn cells_side_by_side_are_written_in_order() {
    let cells = [(0, 0, cell("a", Color::Reset, Modifier::empty())), (1, 0, cell("b", Color::Reset, Modifier::empty()))];

    assert!(drawn(Depth::TrueColour, &cells).text().starts_with("ab"));
}

#[test]
fn a_colour_is_written_in_24_bit_where_the_terminal_has_it() {
    let grid = drawn(Depth::TrueColour, &[(0, 0, cell("x", Color::Rgb(10, 200, 30), Modifier::empty()))]);

    assert_eq!(grid.cells[0][0].fg, Colour::Rgb(10, 200, 30));
}

#[test]
fn a_colour_is_the_nearest_of_256_where_the_terminal_has_only_those() {
    let grid = drawn(Depth::Xterm256, &[(0, 0, cell("x", Color::Rgb(255, 0, 0), Modifier::empty()))]);

    assert_eq!(grid.cells[0][0].fg, Colour::Idx(196));
}

#[test]
fn a_background_is_written_too() {
    let mut paper = Cell::default();
    paper.set_bg(Color::Rgb(46, 20, 26));

    assert_eq!(drawn(Depth::TrueColour, &[(0, 0, paper)]).cells[0][0].bg, Colour::Rgb(46, 20, 26));
}

#[test]
fn a_named_colour_is_the_terminal_s_own() {
    let grid = drawn(Depth::TrueColour, &[(0, 0, cell("x", Color::Yellow, Modifier::empty()))]);

    assert_eq!(grid.cells[0][0].fg, Colour::Idx(3));
}

#[test]
fn bold_italic_and_dim_are_written() {
    let cells = [
        (0, 0, cell("b", Color::Reset, Modifier::BOLD)),
        (1, 0, cell("i", Color::Reset, Modifier::ITALIC)),
        (2, 0, cell("d", Color::Reset, Modifier::DIM)),
    ];
    let grid = drawn(Depth::TrueColour, &cells);

    assert_eq!([0, 1, 2].map(|x| grid.cells[0][x].attrs.clone()), [vec!["bold"], vec!["italic"], vec!["dim"]]);
}

#[test]
fn a_cell_after_a_styled_one_is_plain_again() {
    let cells = [(0, 0, cell("b", Color::Red, Modifier::BOLD)), (1, 0, cell("p", Color::Reset, Modifier::empty()))];
    let grid = drawn(Depth::TrueColour, &cells);

    assert_eq!((grid.cells[0][1].fg, grid.cells[0][1].attrs.clone()), (Colour::Default, Vec::<&str>::new()));
}

#[test]
fn clearing_the_screen_writes_the_clear_and_goes_home() {
    let mut backend = AnsiBackend::new((10, 3), Depth::TrueColour);
    backend.clear_region(ClearType::All).unwrap();

    assert!(backend.take().starts_with(b"\x1b[2J\x1b[H"));
}

#[test]
fn the_backend_says_the_size_it_was_given() {
    let mut backend = AnsiBackend::new((10, 3), Depth::TrueColour);
    backend.resize((80, 24));

    assert_eq!((backend.size().unwrap().width, backend.size().unwrap().height), (80, 24));
}

#[test]
fn taking_the_bytes_empties_the_backend() {
    let mut backend = AnsiBackend::new((10, 3), Depth::TrueColour);
    backend.clear_region(ClearType::All).unwrap();
    let _ = backend.take();

    assert!(backend.take().is_empty());
}

#[test]
fn a_colour_of_the_256_is_written_as_that_colour() {
    let grid = drawn(Depth::TrueColour, &[(0, 0, cell("x", Color::Indexed(208), Modifier::empty()))]);

    assert_eq!(grid.cells[0][0].fg, Colour::Idx(208));
}

#[test]
fn a_bright_named_colour_is_the_terminal_s_bright_one() {
    let grid = drawn(Depth::TrueColour, &[(0, 0, cell("x", Color::LightRed, Modifier::empty()))]);

    assert_eq!(grid.cells[0][0].fg, Colour::Idx(9));
}

#[test]
fn dark_grey_is_the_first_of_the_bright_colours() {
    let grid = drawn(Depth::TrueColour, &[(0, 0, cell("x", Color::DarkGray, Modifier::empty()))]);

    assert_eq!(grid.cells[0][0].fg, Colour::Idx(8));
}

#[test]
fn a_cell_drawn_after_a_clear_lands_where_it_belongs() {
    let mut backend = AnsiBackend::new((10, 3), Depth::TrueColour);
    let red = cell("x", Color::Red, Modifier::empty());
    backend.draw([(0, 0, &red)].into_iter()).unwrap();
    backend.clear_region(ClearType::All).unwrap();
    backend.draw([(1, 0, &cell("y", Color::Red, Modifier::empty()))].into_iter()).unwrap();
    let mut emulator = Emulator::new((10, 3));
    emulator.feed((10, 3), &backend.take());

    assert_eq!((emulator.grid().cells[0][1].text.as_str(), emulator.grid().cells[0][1].fg), ("y", Colour::Idx(1)));
}

#[test]
fn clearing_the_whole_terminal_writes_the_clear() {
    let mut backend = AnsiBackend::new((10, 3), Depth::TrueColour);
    Backend::clear(&mut backend).unwrap();

    assert!(backend.take().starts_with(b"\x1b[2J"));
}

#[test]
fn hiding_the_cursor_writes_the_escape_that_hides_it() {
    let mut backend = AnsiBackend::new((10, 3), Depth::TrueColour);
    backend.hide_cursor().unwrap();

    assert_eq!(backend.take(), b"\x1b[?25l");
}

#[test]
fn showing_the_cursor_writes_the_escape_that_shows_it() {
    let mut backend = AnsiBackend::new((10, 3), Depth::TrueColour);
    backend.show_cursor().unwrap();

    assert_eq!(backend.take(), b"\x1b[?25h");
}

#[test]
fn the_cursor_is_where_it_was_last_put() {
    let mut backend = AnsiBackend::new((10, 3), Depth::TrueColour);
    backend.set_cursor_position(ratatui::layout::Position { x: 4, y: 2 }).unwrap();

    assert_eq!(backend.get_cursor_position().unwrap(), ratatui::layout::Position { x: 4, y: 2 });
}

#[test]
fn putting_the_cursor_somewhere_moves_the_terminal_s_cursor_there() {
    let mut backend = AnsiBackend::new((10, 3), Depth::TrueColour);
    backend.set_cursor_position(ratatui::layout::Position { x: 4, y: 2 }).unwrap();

    assert_eq!(backend.take(), b"\x1b[3;5H");
}
