//! Which scene plays for which occasion. Each milestone has its own pool of
//! scenes (acceptance-tests.md, AT-7.3), and a scene is picked from the pool
//! at random unless a scenario (or a test) pins one.

use crate::animation::{Blank, Library, Scene};
use std::time::{SystemTime, UNIX_EPOCH};

/// The milestones that call for a header scene, in the order a run reaches them.
pub const MILESTONES: [&str; 5] = ["lint_passed", "build_passed", "fast_passed", "run_passed", "run_failed"];
/// Each milestone's scenes, by `MILESTONES` index: small ones for lint and
/// build, bigger for the fast suite, the biggest for a passing run.
const POOLS: [&[&str]; 5] = [
    &["sweep", "ripple"],
    &["bricks", "gears"],
    &["flash", "yay"],
    &["success", "celebrate", "leprechauns"],
    &["explosion"],
];
static MISSING: Blank = Blank("blank");

/// The scene library plus the current choices.
#[derive(Debug, Clone)]
pub struct Cast {
    library: Library,
    pins: [Option<&'static str>; 5],
    seed: u64,
}

impl Cast {
    /// `seed` drives the random choice of unpinned scenes.
    #[must_use]
    pub fn new(library: Library, seed: u64) -> Self {
        Self { library, pins: [None; 5], seed }
    }

    /// The scenes `milestone` picks from; none for anything else.
    #[must_use]
    pub fn pool(milestone: &str) -> &'static [&'static str] {
        MILESTONES.iter().position(|m| *m == milestone).map_or(&[], |index| POOLS[index])
    }

    /// Makes `name` its pool's scene from now on; a name in no pool is ignored.
    pub fn pin(&mut self, name: &str) {
        for (pin, pool) in self.pins.iter_mut().zip(POOLS) {
            if let Some(found) = pool.iter().find(|n| **n == name) {
                *pin = Some(found);
            }
        }
    }

    /// The scene a milestone event calls for, or none for any other event.
    pub fn for_milestone(&mut self, event: &str) -> Option<&'static dyn Scene> {
        let index = MILESTONES.iter().position(|m| *m == event)?;
        let name = self.pins[index].unwrap_or_else(|| self.random(POOLS[index]));
        Some(self.named(name))
    }

    #[must_use]
    pub fn idle(&self) -> &'static dyn Scene {
        self.named("idle")
    }

    /// The scene the header rests on after a run ends with `status`: calm
    /// for a pass, a warning for anything else.
    #[must_use]
    pub fn rest(&self, status: &str) -> &'static dyn Scene {
        self.named(if status == "passed" { "calm" } else { "warning" })
    }

    #[must_use]
    pub fn running(&self) -> &'static dyn Scene {
        self.named("running")
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
