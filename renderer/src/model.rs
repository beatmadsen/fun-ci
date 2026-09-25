//! The `board` message: everything Ruby says is true (renderer-protocol.md).

use serde::Deserialize;

/// The full state to show.
#[derive(Debug, Clone, Default, PartialEq, Eq, Deserialize)]
pub struct Board {
    #[serde(default)]
    pub now: i64,
    #[serde(default)]
    pub streak: Option<u32>,
    #[serde(flatten)]
    pub view: View,
    #[serde(default)]
    pub runs: Vec<Run>,
}

/// What the user is doing: where the cursor is, whether a cancel is being confirmed.
#[derive(Debug, Clone, Default, PartialEq, Eq, Deserialize)]
pub struct View {
    #[serde(default)]
    pub cursor: Option<usize>,
    #[serde(default)]
    pub confirming: bool,
    #[serde(default)]
    pub has_more: bool,
}

/// One pipeline run.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct Run {
    pub id: u64,
    #[serde(flatten)]
    pub commit: Commit,
    #[serde(flatten)]
    pub state: RunState,
    #[serde(default)]
    pub stages: Vec<Stage>,
}

/// Which commit a run is for.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct Commit {
    pub sha: String,
    pub branch: String,
    #[serde(default)]
    pub project: Option<String>,
}

/// A run's status and when it last changed (epoch seconds).
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct RunState {
    pub status: String,
    pub updated_at: i64,
}

/// One stage of a run.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct Stage {
    pub stage: String,
    pub status: String,
    #[serde(default)]
    pub duration_ms: Option<u64>,
    #[serde(default)]
    pub started_at: Option<i64>,
}

/// Something that happened, for the renderer to animate.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct Event {
    pub name: String,
    #[serde(default)]
    pub run_id: Option<u64>,
    #[serde(default)]
    pub stage: Option<String>,
    #[serde(default)]
    pub animation: Option<String>,
}

impl Run {
    #[must_use]
    pub fn status(&self) -> &str {
        &self.state.status
    }

    #[must_use]
    pub fn stage(&self, name: &str) -> Option<&Stage> {
        self.stages.iter().find(|s| s.stage == name)
    }
}
