//! The header's film draws only the cells that changed since the last frame,
//! unless the screen was cleared in between.

use fun_ci_renderer::animator::film::Film;
use fun_ci_renderer::art::cells::Cell;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::screen::Screen;

const RED: Cell = Cell { glyph: ' ', fg: [255, 0, 0], bg: [255, 0, 0] };
const BLUE: Cell = Cell { glyph: ' ', fg: [0, 0, 255], bg: [0, 0, 255] };

fn drawn(bytes: Vec<u8>) -> String {
    String::from_utf8(bytes).unwrap()
}

fn shown(frame: Vec<Vec<Cell>>) -> (Film, Screen) {
    let (mut film, mut screen) = (Film::new(Depth::TrueColour), Screen::new(2));
    film.project(frame, &mut screen);
    screen.take();
    (film, screen)
}

#[test]
fn should_draw_every_cell_at_its_place_when_nothing_was_shown_before() {
    let (mut film, mut screen) = (Film::new(Depth::TrueColour), Screen::new(2));
    film.project(vec![vec![RED]], &mut screen);
    assert_eq!(drawn(screen.take()), "\u{1b}[1;1H\u{1b}[48;2;255;0;0m \u{1b}[0m");
}

#[test]
fn should_draw_nothing_when_the_frame_equals_the_one_shown() {
    let (mut film, mut screen) = shown(vec![vec![RED, RED]]);
    film.project(vec![vec![RED, RED]], &mut screen);
    assert_eq!(drawn(screen.take()), "");
}

#[test]
fn should_draw_only_the_changed_cell_when_one_cell_changed() {
    let (mut film, mut screen) = shown(vec![vec![RED, RED]]);
    film.project(vec![vec![RED, BLUE]], &mut screen);
    assert_eq!(drawn(screen.take()), "\u{1b}[1;2H\u{1b}[48;2;0;0;255m \u{1b}[0m");
}

#[test]
fn should_draw_every_cell_again_when_the_screen_was_cleared_since_the_last_frame() {
    let (mut film, mut screen) = shown(vec![vec![RED]]);
    screen.clear();
    screen.take();
    film.project(vec![vec![RED]], &mut screen);
    assert_eq!(drawn(screen.take()), "\u{1b}[1;1H\u{1b}[48;2;255;0;0m \u{1b}[0m");
}

#[test]
fn should_draw_in_xterm_colours_when_its_depth_is_256() {
    let (mut film, mut screen) = (Film::new(Depth::Xterm256), Screen::new(2));
    film.project(vec![vec![RED]], &mut screen);
    assert_eq!(drawn(screen.take()), "\u{1b}[1;1H\u{1b}[48;5;196m \u{1b}[0m");
}
