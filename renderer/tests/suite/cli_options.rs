//! The command line: colour depth, sizes, paths, and refusal of anything unknown.

use std::path::PathBuf;

use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::cli::Options;

use crate::support::renderer::{Renderer, binary};

fn parse(args: &[&str]) -> Result<Options, String> {
    Options::parse(args.iter().map(ToString::to_string))
}

#[test]
fn should_draw_in_24_bit_colour_when_colorterm_says_truecolor() {
    assert_eq!(parse(&[]).unwrap().depth(Some("truecolor")), Depth::TrueColour);
}

#[test]
fn should_draw_in_24_bit_colour_when_colorterm_says_24bit() {
    assert_eq!(parse(&[]).unwrap().depth(Some("24bit")), Depth::TrueColour);
}

#[test]
fn should_fall_back_to_256_colours_when_colorterm_is_unset() {
    assert_eq!(parse(&[]).unwrap().depth(None), Depth::Xterm256);
}

#[test]
fn should_draw_in_the_colours_asked_for_when_colours_overrides_colorterm() {
    assert_eq!(parse(&["--colours", "256"]).unwrap().depth(Some("truecolor")), Depth::Xterm256);
}

#[test]
fn should_draw_in_24_bit_colour_when_asked_for_whatever_colorterm_says() {
    assert_eq!(parse(&["--colours", "24bit"]).unwrap().depth(None), Depth::TrueColour);
}

#[test]
fn should_refuse_a_colour_depth_when_it_is_neither_24bit_nor_256() {
    assert!(parse(&["--colours", "16"]).is_err());
}

#[test]
fn should_draw_headless_frames_in_24_bit_colour_when_no_depth_is_asked_for() {
    let options = parse(&["--headless", "--scenario", "s.jsonl", "--out", "o"]).unwrap();
    assert_eq!(options.headless().unwrap().unwrap().depth, Depth::TrueColour);
}

#[test]
fn an_unknown_option_is_refused() {
    assert!(parse(&["--dance", "x"]).is_err());
}

#[test]
fn an_option_without_its_value_is_refused() {
    assert!(parse(&["--colours"]).is_err());
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
fn should_exit_with_a_usage_error_when_the_binary_is_given_an_unknown_colour_depth() {
    let mut renderer = Renderer::start(binary().args(["--colours", "16"]));
    assert_eq!(renderer.wait().code(), Some(64));
}

#[test]
fn should_say_its_version_when_asked_for_it_alone() {
    assert_eq!(about(&["--version"]), Some(format!("fun-ci-renderer {}\n", env!("CARGO_PKG_VERSION"))));
}

#[test]
fn should_say_that_fun_ci_console_runs_it_when_asked_for_help() {
    assert!(about(&["--help"]).is_some_and(|text| text.contains("`fun-ci console` starts it")));
}

#[test]
fn should_answer_nothing_but_a_lone_help_or_version() {
    assert_eq!(about(&["--help", "--headless"]), None);
}

#[test]
fn should_answer_nothing_for_a_lone_option_other_than_help_or_version() {
    assert_eq!(about(&["--headless"]), None);
}

#[test]
fn should_print_its_version_and_exit_zero_when_the_binary_is_asked_for_it() {
    let mut renderer = Renderer::start(binary().arg("--version"));
    assert_eq!((renderer.line(), renderer.wait().code()), (format!("fun-ci-renderer {}", env!("CARGO_PKG_VERSION")), Some(0)));
}

fn about(args: &[&str]) -> Option<String> {
    fun_ci_renderer::cli::about(&args.iter().map(ToString::to_string).collect::<Vec<_>>())
}
