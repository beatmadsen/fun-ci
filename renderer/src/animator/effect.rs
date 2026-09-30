//! A short animation over one stage of one run's row, or, for a conflict
//! with the trunk, over none of its stages, in the footer alone; timed from
//! the frame it starts on, by the animation clock.

/// What an effect celebrates or mourns.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Failure,
    Timeout,
    Success,
    StagePass,
    Conflict,
}

impl Kind {
    /// The effect an event calls for, given the stage's and the run's status.
    #[must_use]
    pub fn for_event(event: &str, stage_status: &str, run_status: &str) -> Option<Self> {
        match (event, stage_status, run_status) {
            ("stage_failed", "timeout", _) => Some(Self::Timeout),
            ("stage_failed", ..) => Some(Self::Failure),
            ("stage_passed", _, "passed") => Some(Self::Success),
            ("stage_passed", ..) => Some(Self::StagePass),
            ("trunk_conflict", ..) => Some(Self::Conflict),
            _ => None,
        }
    }

    /// How long it plays, in milliseconds.
    #[must_use]
    pub fn lasts_ms(self) -> u64 {
        match self {
            Self::Failure | Self::Success | Self::Conflict => 4_000,
            Self::Timeout => 400,
            Self::StagePass => 300,
        }
    }

    #[must_use]
    pub fn priority(self) -> u8 {
        match self {
            Self::Failure => 3,
            Self::Timeout | Self::Conflict => 2,
            Self::Success => 1,
            Self::StagePass => 0,
        }
    }

    #[must_use]
    pub fn has_footer(self) -> bool {
        matches!(self, Self::Failure | Self::Success | Self::Conflict)
    }
}

/// One playing effect, and the animation clock when it started.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Effect {
    pub kind: Kind,
    pub run_id: u64,
    pub stage: String,
    pub started_ms: u64,
}

impl Effect {
    #[must_use]
    pub fn new(kind: Kind, (run_id, stage): (u64, &str), started_ms: u64) -> Self {
        Self { kind, run_id, stage: stage.to_string(), started_ms }
    }

    /// How long it has played by `play_ms`.
    #[must_use]
    pub fn elapsed_ms(&self, play_ms: u64) -> u64 {
        play_ms.saturating_sub(self.started_ms)
    }

    #[must_use]
    pub fn finished(&self, play_ms: u64) -> bool {
        self.elapsed_ms(play_ms) >= self.kind.lasts_ms()
    }

    #[must_use]
    pub fn is_for(&self, kind: Kind, run_id: u64, stage: &str) -> bool {
        self.kind == kind && self.run_id == run_id && self.stage == stage
    }
}
