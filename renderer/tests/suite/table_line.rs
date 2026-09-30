//! A line of the table, cell by cell: its text in each part's colour, bold
//! or in italics.

use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::grid::{Emulator, Grid};
use fun_ci_renderer::table::line::{Line, Style};

fn drawn(line: &Line) -> Grid {
    let mut emulator = Emulator::new((20, 1));
    emulator.feed((20, 1), line.encode(Depth::TrueColour).as_bytes());
    emulator.grid()
}

#[test]
fn an_italic_part_is_drawn_in_italics() {
    let mut line = Line::new(20, None);
    line.put(0, "note", Style::italic([200, 200, 200]));

    assert_eq!(drawn(&line).cells[0][0].attrs, vec!["italic"]);
}

#[test]
fn a_plain_part_after_an_italic_one_is_upright() {
    let mut line = Line::new(20, None);
    line.put(0, "note", Style::italic([200, 200, 200]));
    line.put(5, "word", Style::plain([200, 200, 200]));

    assert!(drawn(&line).cells[0][5].attrs.is_empty());
}
