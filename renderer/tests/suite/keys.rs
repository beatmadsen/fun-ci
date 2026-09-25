//! The bytes a raw-mode terminal sends become the key names of the `key`
//! message (renderer-protocol.md).

use fun_ci_renderer::keys::decode;

#[test]
fn a_printable_character_is_its_own_key() {
    assert_eq!(decode(b"j"), ["j"]);
}

#[test]
fn a_multibyte_character_is_one_key() {
    assert_eq!(decode("é".as_bytes()), ["é"]);
}

#[test]
fn every_key_in_one_read_is_reported_in_order() {
    assert_eq!(decode(b"jk"), ["j", "k"]);
}

#[test]
fn the_up_arrow_is_up() {
    assert_eq!(decode(b"\x1b[A"), ["up"]);
}

#[test]
fn the_down_arrow_is_down() {
    assert_eq!(decode(b"\x1b[B"), ["down"]);
}

#[test]
fn the_arrows_in_application_cursor_mode_are_up_and_down() {
    assert_eq!(decode(b"\x1bOA\x1bOB"), ["up", "down"]);
}

#[test]
fn carriage_return_is_enter() {
    assert_eq!(decode(b"\r"), ["enter"]);
}

#[test]
fn line_feed_is_enter() {
    assert_eq!(decode(b"\n"), ["enter"]);
}

#[test]
fn a_lone_escape_is_esc() {
    assert_eq!(decode(b"\x1b"), ["esc"]);
}

#[test]
fn escape_then_a_character_is_esc_then_the_character() {
    assert_eq!(decode(b"\x1bq"), ["esc", "q"]);
}

#[test]
fn ctrl_c_is_ctrl_c() {
    assert_eq!(decode(b"\x03"), ["ctrl_c"]);
}

#[test]
fn other_control_bytes_are_no_key() {
    assert_eq!(decode(b"\x01\x7f"), Vec::<String>::new());
}

#[test]
fn an_escape_sequence_for_another_key_is_no_key() {
    assert_eq!(decode(b"\x1b[C\x1b[1;5Dj"), ["j"]);
}

#[test]
fn bytes_that_are_not_utf8_are_no_key() {
    assert_eq!(decode(b"\xffj"), ["j"]);
}
