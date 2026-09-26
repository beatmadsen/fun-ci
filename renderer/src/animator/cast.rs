//! Which scene plays for which occasion. Each milestone has its own pool of
//! scenes (acceptance-tests.md, AT-7.3), and a scene is picked from the pool
//! at random unless a scenario (or a test) pins one.

use crate::animation::{Blank, Library, Scene};
use std::time::{SystemTime, UNIX_EPOCH};

/// Each milestone that calls for a header scene, in the order a run reaches
/// them, with its scenes: small ones for lint and build, bigger for the fast
/// suite, the biggest for a passing run.
const POOLS: [(&str, &[&str]); 5] = [
    ("lint_passed", &["sweep", "ripple"]),
    ("build_passed", &["bricks", "gears"]),
    ("fast_passed", &["flash", "yay"]),
    ("run_passed", &["success", "celebrate", "leprechauns"]),
    ("run_failed", &["explosion"]),
];
/// The milestones, as `POOLS` names them.
pub const MILESTONES: [&str; POOLS.len()] = {
    let mut names = [""; POOLS.len()];
    let mut i = 0;
    while i < POOLS.len() {
        names[i] = POOLS[i].0;
        i += 1;
    }
    names
};
static MISSING: Blank = Blank("blank");

/// The scene library plus the current choices.
#[derive(Debug, Clone)]
pub struct Cast {
    library: Library,
    pins: Vec<&'static str>,
    seed: u64,
}

impl Cast {
    /// `seed` drives the random choice of unpinned scenes.
    #[must_use]
    pub fn new(library: Library, seed: u64) -> Self {
        Self { library, pins: Vec::new(), seed }
    }

    /// The scenes `milestone` picks from; none for anything else.
    #[must_use]
    pub fn pool(milestone: &str) -> &'static [&'static str] {
        POOLS.iter().find(|(name, _)| *name == milestone).map_or(&[], |(_, pool)| *pool)
    }

    /// Makes `name` its pool's scene from now on; a name in no pool is ignored.
    pub fn pin(&mut self, name: &str) {
        let Some(pool) = POOLS.iter().map(|(_, pool)| *pool).find(|pool| pool.contains(&name)) else { return };
        self.pins.retain(|pinned| !pool.contains(pinned));
        self.pins.extend(pool.iter().find(|scene| **scene == name));
    }

    /// The scene a milestone event calls for, or none for any other event.
    pub fn for_milestone(&mut self, event: &str) -> Option<&'static dyn Scene> {
        let pool = Self::pool(event);
        let pinned = self.pins.iter().copied().find(|pinned| pool.contains(pinned));
        let name = pinned.or_else(|| (!pool.is_empty()).then(|| self.random(pool)))?;
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
