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
    assert_eq!(parse(&["--animations", "anim"]).unwrap().animations, Some(PathBuf::from("anim")));
}

#[test]
fn no_arguments_mean_the_embedded_animations() {
    assert_eq!(parse(&[]).unwrap().animations, None);
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
