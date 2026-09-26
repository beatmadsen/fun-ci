//! Scenes paint the same pixels on every platform only if their maths is the
//! same everywhere: art and scene code calls `art::math::Portable`, never the
//! standard library's platform-dependent transcendental functions.

use std::fs;
use std::path::Path;

const PLATFORM_CALLS: [&str; 9] = [".sin(", ".cos(", ".tan(", ".exp(", ".ln(", ".log(", ".powf(", ".hypot(", ".atan2("];

fn offences(dir: &str) -> Vec<String> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join(dir);
    let sources = fs::read_dir(&root).unwrap().map(|entry| entry.unwrap().path());
    let read = |path: std::path::PathBuf| (path.display().to_string(), fs::read_to_string(&path).unwrap());
    let calls = |(path, text): (String, String)| PLATFORM_CALLS.iter().filter(|call| text.contains(*call)).map(|call| format!("{path}: {call}")).collect::<Vec<_>>();
    sources.filter(|path| !path.ends_with("math.rs")).map(read).flat_map(calls).collect()
}

#[test]
fn should_find_no_platform_maths_in_the_art_code() {
    assert_eq!(offences("src/art"), Vec::<String>::new());
}

#[test]
fn should_find_no_platform_maths_in_the_scenes() {
    assert_eq!(offences("src/scenes"), Vec::<String>::new());
}
