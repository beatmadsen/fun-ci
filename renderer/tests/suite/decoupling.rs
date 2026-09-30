//! The table and the animations are drawn apart: the table says where it put
//! each run's row and marks, and the compositor (`board_view`) hands that to
//! the effects as places. Neither side imports the other, so either can be
//! redrawn without the other noticing; what both need lives in modules of
//! their own (`model`, `maths`, `output`).

use std::fs;
use std::path::{Path, PathBuf};

const TABLE: [&str; 1] = ["table"];
const ANIMATION: [&str; 4] = ["animator", "animation", "art", "scenes"];

/// Every Rust source under `src/<dir>`, however deep.
fn sources(dir: &str) -> Vec<PathBuf> {
    let mut found = Vec::new();
    let mut pending = vec![Path::new(env!("CARGO_MANIFEST_DIR")).join("src").join(dir)];
    while let Some(dir) = pending.pop() {
        for path in fs::read_dir(dir).unwrap().map(|entry| entry.unwrap().path()) {
            if path.is_dir() { pending.push(path) } else { found.push(path) }
        }
    }
    found
}

/// The top-level modules `text` names through the crate root, grouped (`crate::{a, b::c}`) or not.
fn named(text: &str) -> Vec<String> {
    let after = text.split("crate::").skip(1);
    let group = |rest: &str| rest.strip_prefix('{').map_or_else(|| rest.to_string(), |inner| inner.split('}').next().unwrap_or_default().to_string());
    let heads = |list: String| list.split(',').map(|path| path.trim().split("::").next().unwrap_or_default().trim_matches(|c: char| !c.is_alphanumeric() && c != '_').to_string()).collect::<Vec<_>>();
    after.map(group).flat_map(heads).collect()
}

/// Each place in `from`'s sources that names a module of `to` through the crate root.
fn crossings(from: &[&str], to: &[&str]) -> Vec<String> {
    let paths = from.iter().flat_map(|dir| sources(dir));
    let found = |path: PathBuf| {
        let modules = named(&fs::read_to_string(&path).unwrap());
        to.iter().filter(|module| modules.iter().any(|named| named == *module)).map(|module| format!("{}: crate::{module}", path.display())).collect::<Vec<_>>()
    };
    paths.flat_map(found).collect()
}

#[test]
fn the_table_names_nothing_of_the_animations() {
    assert_eq!(crossings(&TABLE, &[&ANIMATION[..], &["board_view"]].concat()), Vec::<String>::new());
}

#[test]
fn the_animations_name_nothing_of_the_table() {
    assert_eq!(crossings(&ANIMATION, &["table", "board_view"]), Vec::<String>::new());
}
