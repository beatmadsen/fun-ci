//! A daily or weekly job on the `board` (renderer-protocol.md, `board`).

use serde::Deserialize;

/// How a daily or weekly job stands (renderer-protocol.md, `board`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum JobStatus {
    /// It never ran, or its latest run was cancelled: the next commit starts it.
    Due,
    /// A commit started it, and it waits its turn to start (`starts_at`).
    Scheduled,
    Running,
    Passed,
    Failed,
    /// It ran out of time.
    Timeout,
    /// Its process died before it said how the run ended.
    Lost,
    /// A state a newer fun-ci, sharing the database, sent.
    #[serde(other)]
    Unknown,
}

/// A daily or weekly job: how often it runs, and its latest run, or that it
/// is due (renderer-protocol.md, `board`). Times are epoch seconds.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct Job {
    #[serde(default)]
    pub project: Option<String>,
    pub name: String,
    pub cadence: String,
    pub status: JobStatus,
    #[serde(default)]
    pub run_id: Option<u64>,
    #[serde(default)]
    pub sha: Option<String>,
    #[serde(default)]
    pub branch: Option<String>,
    #[serde(default)]
    pub started_at: Option<i64>,
    /// When its latest run ended, or started while it runs.
    #[serde(default)]
    pub updated_at: Option<i64>,
    /// When it is due again; none while it is due now, or runs.
    #[serde(default)]
    pub due_at: Option<i64>,
    /// When a job waiting its turn starts; none for any other.
    #[serde(default)]
    pub starts_at: Option<i64>,
    /// How the user hid it, on a board that shows hidden jobs; none for a job in view.
    #[serde(default)]
    pub hidden: Option<Hidden>,
}

/// How the user hid a job (design.md, The console).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Hidden {
    /// Until it runs again.
    Snoozed,
    /// Until the user shows it again.
    Ignored,
    /// A way a newer fun-ci, sharing the database, sent.
    #[serde(other)]
    Otherwise,
}
