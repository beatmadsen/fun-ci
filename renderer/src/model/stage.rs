//! The pipeline's stages and what each is called on screen.

/// The pipeline's stages in the order they run, whatever order a run lists them in.
pub const STAGES: [&str; 4] = ["lint", "build", "fast", "slow"];

/// A stage as someone who has never seen fun-ci would read it: `lint`,
/// `build`, `fast suite`, `slow suite`.
#[must_use]
pub fn stage_name(stage: &str) -> &str {
    match stage {
        "fast" => "fast suite",
        "slow" => "slow suite",
        other => other,
    }
}

/// A stage in a sentence: `lint`, `the build`, `the fast suite`, `the slow suite`.
#[must_use]
pub fn stage_noun(stage: &str) -> String {
    if stage == "lint" { stage.to_string() } else { format!("the {}", stage_name(stage)) }
}
