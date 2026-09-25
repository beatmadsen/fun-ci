//! The command line: `--animations <dir>` and refusal of anything unknown.

use std::fs;
use std::path::PathBuf;
use std::process::Command;

use fun_ci_renderer::cli::Options;

fn parse(args: &[&str]) -> Result<Options, String> {
    Options::parse(args.iter().map(ToString::to_string))
}

#[test]
fn animations_names_a_directory() {
    assert_eq!(parse(&["--animations", "anim"]).unwrap().paths.animations, Some(PathBuf::from("anim")));
}

#[test]
fn no_arguments_mean_the_embedded_animations() {
    assert_eq!(parse(&[]).unwrap().paths.animations, None);
}

#[test]
fn an_unknown_option_is_refused() {
    assert!(parse(&["--dance", "x"]).is_err());
}

#[test]
fn an_option_without_its_value_is_refused() {
    assert!(parse(&["--animations"]).is_err());
}

#[test]
fn cols_set_the_headless_terminal_width() {
    assert_eq!(parse(&["--cols", "120"]).unwrap().size, (120, 24));
}

#[test]
fn rows_set_the_headless_terminal_height() {
    assert_eq!(parse(&["--rows", "40"]).unwrap().size, (80, 40));
}

#[test]
fn a_size_that_is_not_a_positive_number_is_refused() {
    assert!(parse(&["--cols", "0"]).is_err());
}

#[test]
fn headless_takes_no_value() {
    let options = parse(&["--headless", "--scenario", "s.jsonl", "--out", "o"]).unwrap();
    assert_eq!(options.headless().unwrap().unwrap().scenario, PathBuf::from("s.jsonl"));
}

#[test]
fn headless_needs_an_output_directory() {
    assert!(parse(&["--headless", "--scenario", "s.jsonl"]).unwrap().headless().is_err());
}

#[test]
fn without_headless_the_renderer_runs_live() {
    assert_eq!(parse(&["--out", "o"]).unwrap().headless(), Ok(None));
}

#[test]
fn a_live_session_draws_on_the_controlling_terminal() {
    assert_eq!(parse(&[]).unwrap().tty(), PathBuf::from("/dev/tty"));
}

#[test]
fn tty_names_the_terminal_to_draw_on() {
    assert_eq!(parse(&["--tty", "/dev/ttys042"]).unwrap().tty(), PathBuf::from("/dev/ttys042"));
}

#[test]
fn the_library_takes_animations_from_the_named_directory() {
    let dir = tempfile::tempdir().unwrap();
    let json = fs::read_to_string("animations/explosion.json").unwrap().replace("\"explosion\"", "\"boom\"");
    fs::write(dir.path().join("boom.json"), json).unwrap();
    let options = parse(&["--animations", dir.path().to_str().unwrap()]).unwrap();
    assert!(options.library().unwrap().get("boom").is_some());
}

#[test]
fn the_binary_refuses_an_animations_directory_it_cannot_read() {
    let dir = tempfile::tempdir().unwrap();
    let missing = dir.path().join("missing");
    let status = Command::new(env!("CARGO_BIN_EXE_fun-ci-renderer"))
        .args(["--animations", missing.to_str().unwrap()])
        .status()
        .unwrap();
    assert_eq!(status.code(), Some(64));
}
