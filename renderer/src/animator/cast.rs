//! Which scene plays for which occasion. A scenario (or a test) may pin the
//! choice; otherwise success scenes are picked at random.

use crate::animation::{Blank, Library, Scene};
use std::time::{SystemTime, UNIX_EPOCH};

const FAILURES: [&str; 1] = ["explosion"];
const SUCCESSES: [&str; 5] = ["success", "celebrate", "flash", "leprechauns", "yay"];
static MISSING: Blank = Blank("blank");

#[derive(Debug, Clone, Default)]
struct Pins {
    failure: Option<&'static str>,
    success: Option<&'static str>,
}

/// The scene library plus the current choices.
#[derive(Debug, Clone)]
pub struct Cast {
    library: Library,
    pins: Pins,
    seed: u64,
}

impl Cast {
    /// `seed` drives the random choice of unpinned scenes.
    #[must_use]
    pub fn new(library: Library, seed: u64) -> Self {
        Self { library, pins: Pins::default(), seed }
    }

    /// Makes `name` the failure or success scene from now on; a name that is
    /// neither is ignored.
    pub fn pin(&mut self, name: &str) {
        if let Some(failure) = FAILURES.iter().find(|n| **n == name) {
            self.pins.failure = Some(failure);
        } else if let Some(success) = SUCCESSES.iter().find(|n| **n == name) {
            self.pins.success = Some(success);
        }
    }

    #[must_use]
    pub fn idle(&self) -> &'static dyn Scene {
        self.named("idle")
    }

    #[must_use]
    pub fn running(&self) -> &'static dyn Scene {
        self.named("running")
    }

    pub fn failure(&mut self) -> &'static dyn Scene {
        let name = self.pins.failure.unwrap_or_else(|| self.random(&FAILURES));
        self.named(name)
    }

    pub fn success(&mut self) -> &'static dyn Scene {
        let name = self.pins.success.unwrap_or_else(|| self.random(&SUCCESSES));
        self.named(name)
    }

    fn random(&mut self, names: &[&'static str]) -> &'static str {
        self.seed ^= self.seed << 13;
        self.seed ^= self.seed >> 7;
        self.seed ^= self.seed << 17;
        let index = usize::try_from(self.seed % names.len() as u64).unwrap_or_default();
        names[index]
    }

    fn named(&self, name: &str) -> &'static dyn Scene {
        self.library.get(name).unwrap_or(&MISSING)
    }
}

/// A seed for `Cast` from the time `now`: its nanoseconds past the second,
/// with the low bit set, so it differs from run to run and is never zero,
/// which the generator would never leave.
#[must_use]
pub fn seed_at(now: SystemTime) -> u64 {
    now.duration_since(UNIX_EPOCH).map_or(1, |since| u64::from(since.subsec_nanos()) | 1)
}
