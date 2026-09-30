//! The legend over the first row (design.md, The console): each stage's name
//! above its own mark, with a line down to it from each name after, and what
//! the stage is for, so the marks mean something to someone who has never
//! seen fun-ci. When any description would run off the screen, all are left out.


use super::STAGES;
use super::night::{LABEL, NIGHT, NOTE, blend, ink};
use super::paint::{Paint, Part};
use crate::format::columns;
use crate::model::stage_name;

/// What each stage is for, in lint, build, fast, slow order.
pub const PURPOSES: [&str; 4] = [
    "checks the code without running it",
    "compiles the code and its tests",
    "quick tests, after lint and the build",
    "long tests, run in the background",
];

/// The legend on one line, for when the table has no room for the full one:
/// said above the footer, in the line the table leaves blank there.
pub const KEY: &str = "marks, left to right: lint · build · fast suite · slow suite";
/// The same, for a narrow screen.
pub const KEY_BRIEFLY: &str = "marks: lint · build · fast suite · slow suite";

/// The one-line legend that fits `width` columns from column `at`.
#[must_use]
pub fn key(width: u16, at: usize) -> &'static str {
    if at + columns(KEY) <= usize::from(width) { KEY } else { KEY_BRIEFLY }
}

/// Between a stage's name and what it is for.
const APART: &str = " · ";

/// Line `n` of the legend: a leader over each earlier stage's mark, then
/// stage `n`'s name over its own, and what it is for if the screen has room.
#[must_use]
pub fn legend(n: usize, paint: &Paint) -> Vec<Part> {
    let at = |i: usize| paint.columns.strip + 2 * i;
    let mut parts: Vec<Part> = (0..n).map(|i| (at(i), "│".to_string(), ink(blend(NIGHT, LABEL, 0.6)))).collect();
    let name = stage_name(STAGES[n]).to_string();
    let after = at(n) + columns(&name);
    parts.push((at(n), name, ink(LABEL).bold()));
    parts.extend(described(paint).then(|| (after, format!("{APART}{}", PURPOSES[n]), ink(NOTE).italic())));
    parts
}

/// Whether every stage's description fits on the screen beside its name.
fn described(paint: &Paint) -> bool {
    let end = |i: usize| paint.columns.strip + 2 * i + columns(stage_name(STAGES[i])) + columns(APART) + columns(PURPOSES[i]);
    (0..STAGES.len()).all(|i| end(i) + paint.columns.margin <= usize::from(paint.frame.width))
}
