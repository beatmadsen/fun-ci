//! A short animation over one stage of one run's row.

/// What an effect celebrates or mourns.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Failure,
    Timeout,
    Success,
    StagePass,
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
            _ => None,
        }
    }

    #[must_use]
    pub fn total_frames(self) -> usize {
        match self {
            Self::Failure | Self::Success => 40,
            Self::Timeout => 4,
            Self::StagePass => 3,
        }
    }

    #[must_use]
    pub fn priority(self) -> u8 {
        match self {
            Self::Failure => 3,
            Self::Timeout => 2,
            Self::Success => 1,
            Self::StagePass => 0,
        }
    }

    #[must_use]
    pub fn has_footer(self) -> bool {
        matches!(self, Self::Failure | Self::Success)
    }
}

/// One playing effect.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Effect {
    pub kind: Kind,
    pub run_id: u64,
    pub stage: String,
    pub frame: usize,
}

impl Effect {
    #[must_use]
    pub fn new(kind: Kind, run_id: u64, stage: &str) -> Self {
        Self { kind, run_id, stage: stage.to_string(), frame: 0 }
    }

    #[must_use]
    pub fn finished(&self) -> bool {
        self.frame >= self.kind.total_frames()
    }

    #[must_use]
    pub fn is_for(&self, kind: Kind, run_id: u64, stage: &str) -> bool {
        self.kind == kind && self.run_id == run_id && self.stage == stage
    }
}
