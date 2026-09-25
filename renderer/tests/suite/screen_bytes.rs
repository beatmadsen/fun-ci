//! The escapes each Screen primitive writes. The golden bytes and the 1.x
//! `Screen` use these exact sequences; a grid comparison cannot see some of
//! them (a clear before a full redraw, a cursor save the emulator ignores).

use fun_ci_renderer::screen::Screen;

macro_rules! writes {
    ($($name:ident: $draw:expr => $bytes:expr;)*) => {
        $(#[test] fn $name() {
            let mut screen = Screen::new(80);
            let draw: fn(&mut Screen) = $draw;
            draw(&mut screen);
            assert_eq!(String::from_utf8(screen.take()).unwrap(), $bytes);
        })*
    };
}

writes! {
    clear_erases_the_screen_and_homes_the_cursor: |s| s.clear() => "\u{1b}[2J\u{1b}[H";
    home_moves_the_cursor_to_the_top_left: |s| s.home() => "\u{1b}[H";
    clear_below_erases_from_the_cursor_down: |s| s.clear_below() => "\u{1b}[J";
    save_cursor_uses_the_ansi_save: |s| s.save_cursor() => "\u{1b}[s";
    restore_cursor_uses_the_ansi_restore: |s| s.restore_cursor() => "\u{1b}[u";
    println_erases_the_rest_of_the_line_and_returns_the_carriage: |s| s.println("hi") => "hi\u{1b}[K\r\n";
    write_at_moves_then_writes: |s| s.write_at(3, 5, "x") => "\u{1b}[3;5Hx";
    a_new_width_clears_the_screen: |s| s.set_width(100) => "\u{1b}[2J\u{1b}[H";
    the_same_width_draws_nothing: |s| s.set_width(80) => "";
    the_first_height_clears_the_screen: |s| s.set_height(24) => "\u{1b}[2J\u{1b}[H";
    the_same_height_again_draws_nothing: |s| { s.set_height(24); s.take(); s.set_height(24); } => "";
}

#[test]
fn the_height_is_the_one_last_set() {
    let mut screen = Screen::new(80);
    screen.set_height(30);
    assert_eq!(screen.height(), Some(30));
}

#[test]
fn the_width_is_the_one_last_set() {
    let mut screen = Screen::new(80);
    screen.set_width(120);
    assert_eq!(screen.width(), 120);
}

#[test]
fn take_empties_the_buffer() {
    let mut screen = Screen::new(80);
    screen.home();
    screen.take();
    assert!(screen.take().is_empty());
}
