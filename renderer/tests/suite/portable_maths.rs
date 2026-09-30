//! Scenes paint the same pixels, and the table breathes the same shades, on
//! every platform only if their maths is the same everywhere: art, scene and
//! table code calls `maths::Portable`, never the standard library's
//! platform-dependent transcendental functions.

use std::fs;
use std::path::Path;

const PLATFORM_CALLS: [&str; 9] = [".sin(", ".cos(", ".tan(", ".exp(", ".ln(", ".log(", ".powf(", ".hypot(", ".atan2("];

fn offences(dir: &str) -> Vec<String> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join(dir);
    let sources = fs::read_dir(&root).unwrap().map(|entry| entry.unwrap().path());
    let read = |path: std::path::PathBuf| (path.display().to_string(), fs::read_to_string(&path).unwrap());
    let calls = |(path, text): (String, String)| PLATFORM_CALLS.iter().filter(|call| text.contains(*call)).map(|call| format!("{path}: {call}")).collect::<Vec<_>>();
    sources.map(read).flat_map(calls).collect()
}

#[test]
fn should_find_no_platform_maths_in_the_art_code() {
    assert_eq!(offences("src/art"), Vec::<String>::new());
}

#[test]
fn should_find_no_platform_maths_in_the_scenes() {
    assert_eq!(offences("src/scenes"), Vec::<String>::new());
}

#[test]
fn should_find_no_platform_maths_in_the_table() {
    assert_eq!(offences("src/table"), Vec::<String>::new());
}

/// tachyonfx with its `std` feature eases some curves with the platform's
/// `powf`; without it, with its own maths.
#[test]
fn should_build_tachyonfx_without_the_platform_s_maths() {
    let manifest = fs::read_to_string(Path::new(env!("CARGO_MANIFEST_DIR")).join("Cargo.toml")).unwrap();
    let line = manifest.lines().find(|line| line.starts_with("tachyonfx")).unwrap_or_default();

    assert!(line.contains("default-features = false") && !line.contains("\"std\""), "{line}");
}
