//! How loudly a row speaks: the newest run of its branch at full colour, a
//! run a newer one replaced dimmed with its hue kept, and a cancelled run
//! faint and colourless.

use super::palette::{FAINT, dimmed};
use crate::model::Run;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Tone {
    Current,
    Replaced,
    Faint,
}

impl Tone {
    /// The tone of `run`; `newest` when no newer run of its branch is on screen.
    #[must_use]
    pub fn of(run: &Run, newest: bool) -> Self {
        match run.status() {
            "cancelled" => Self::Faint,
            _ if newest => Self::Current,
            _ => Self::Replaced,
        }
    }

    /// `colour` in this tone.
    #[must_use]
    pub fn colour(self, colour: [u8; 3]) -> [u8; 3] {
        match self {
            Self::Current => colour,
            Self::Replaced => dimmed(colour),
            Self::Faint => FAINT,
        }
    }

    /// Whether what is bold at full colour stays bold.
    #[must_use]
    pub fn bold(self) -> bool {
        self == Self::Current
    }
}

/// For each run, newest first, whether it is the newest of its project's
/// branch; a run still waiting to start replaces none, so the result before
/// it stays in charge.
#[must_use]
pub fn newest_of_branch(runs: &[Run]) -> Vec<bool> {
    let key = |run: &Run| (run.commit.project.clone(), run.commit.branch.clone());
    let replaces = |newer: &Run, run: &Run| newer.status() != "pending" && key(newer) == key(run);
    runs.iter().enumerate().map(|(i, run)| !runs[..i].iter().any(|newer| replaces(newer, run))).collect()
}
