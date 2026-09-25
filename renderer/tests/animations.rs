//! AT-3.6: animations are data. The renderer embeds `renderer/animations/*.json`
//! and `--animations <dir>` replaces them by name at runtime.

use std::fs;

use fun_ci_renderer::animation::{Animation, Library};

const TINY: &str = r#"{"name":"idle","frame_ms":250,"loop":true,"anchor":"header",
  "styles":{"a":{"fg":1,"bold":true}},
  "frames":[{"text":["*."],"style":["a "]}]}"#;

fn tiny() -> Animation {
    Animation::from_json(TINY).unwrap()
}

#[test]
fn every_converted_animation_is_embedded() {
    let names = ["celebrate", "explosion", "flash", "idle", "leprechauns", "running", "success", "yay"];
    assert_eq!(Library::builtin().names(), names);
}

#[test]
fn an_embedded_animation_keeps_its_frame_count() {
    assert_eq!(Library::builtin().get("explosion").unwrap().frames().len(), 8);
}

#[test]
fn a_line_draws_its_styled_characters_as_sgr_escapes() {
    assert_eq!(tiny().frames()[0][0].ansi(), "\u{1b}[0;1;31m*\u{1b}[0m.");
}

#[test]
fn a_line_knows_its_visible_width() {
    assert_eq!(tiny().frames()[0][0].width(), 2);
}

#[test]
fn a_line_that_ends_styled_is_reset() {
    let json = TINY.replace(r#""style":["a "]"#, r#""style":["aa"]"#);
    assert_eq!(Animation::from_json(&json).unwrap().frames()[0][0].ansi(), "\u{1b}[0;1;31m*.\u{1b}[0m");
}

#[test]
fn colours_above_fifteen_use_the_256_colour_escape() {
    let json = TINY.replace(r#""fg":1,"#, r#""fg":208,"#);
    assert_eq!(Animation::from_json(&json).unwrap().frames()[0][0].ansi(), "\u{1b}[0;1;38;5;208m*\u{1b}[0m.");
}

#[test]
fn bright_colours_use_the_bright_escape() {
    let json = TINY.replace(r#""fg":1,"bold":true"#, r#""fg":9,"dim":true"#);
    assert_eq!(Animation::from_json(&json).unwrap().frames()[0][0].ansi(), "\u{1b}[0;2;91m*\u{1b}[0m.");
}

#[test]
fn a_mask_shorter_than_its_text_is_refused() {
    let json = TINY.replace(r#""style":["a "]"#, r#""style":["a"]"#);
    assert!(Animation::from_json(&json).is_err());
}

#[test]
fn a_mask_naming_an_unknown_style_is_refused() {
    let json = TINY.replace(r#""style":["a "]"#, r#""style":["z "]"#);
    assert!(Animation::from_json(&json).is_err());
}

#[test]
fn the_loop_flag_is_read() {
    assert!(tiny().playback().looped);
}

#[test]
fn a_directory_replaces_the_embedded_animation_of_the_same_name() {
    let dir = tempfile::tempdir().unwrap();
    fs::write(dir.path().join("idle.json"), TINY).unwrap();
    let mut library = Library::builtin();
    library.load_dir(dir.path()).unwrap();
    assert_eq!(library.get("idle").unwrap().frames().len(), 1);
}

#[test]
fn a_directory_that_does_not_exist_is_an_error() {
    let dir = tempfile::tempdir().unwrap();
    assert!(Library::builtin().load_dir(&dir.path().join("missing")).is_err());
}

#[test]
fn a_broken_file_in_the_directory_is_an_error() {
    let dir = tempfile::tempdir().unwrap();
    fs::write(dir.path().join("idle.json"), "{").unwrap();
    assert!(Library::builtin().load_dir(dir.path()).is_err());
}
