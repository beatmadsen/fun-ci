//! Which scene plays for which occasion. Each milestone has its own pool of
//! scenes (acceptance-tests.md, AT-7.3), and a scene is picked from the pool
//! at random unless a scenario (or a test) pins one.

use crate::animation::{Blank, Library, Scene};
use std::time::{SystemTime, UNIX_EPOCH};

/// Each milestone that calls for a header scene, in the order a run reaches
/// them, with its scenes: small ones for lint and build, bigger for the fast
/// suite, the biggest for a passing run.
const POOLS: [(&str, &[&str]); 5] = [
    ("lint_passed", &["sweep", "ripple", "level"]),
    ("build_passed", &["bricks", "gears", "anvil"]),
    ("fast_passed", &["flash", "yay", "warp"]),
    ("run_passed", &["success", "celebrate", "leprechauns", "sunrise"]),
    ("run_failed", &["explosion", "shatter"]),
];
/// The trunk's events, each with its own scenes: small ones, like lint's and
/// build's, telling a branch that has started or stopped conflicting with
/// the trunk (architecture.md, Checking against the trunk).
const TRUNK_POOLS: [(&str, &[&str]); 2] = [("trunk_conflict", &["tangle"]), ("trunk_clear", &["untie"])];
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
/// The quiet scenes: the header shows one when nothing has happened for a while.
const QUIET: [&str; 6] = ["idle", "aurora", "fireflies", "fireplace", "island", "snowfall"];
/// How long one quiet scene shows before another takes over.
const QUIET_TURN_MS: u64 = 5 * 60 * 1000;
static MISSING: Blank = Blank("blank");

/// The scene library plus the current choices.
#[derive(Debug, Clone)]
pub struct Cast {
    library: Library,
    pins: Vec<&'static str>,
    seed: u64,
    /// The quiet scene showing, and when on the play clock it took over.
    quiet: Option<(&'static str, u64)>,
}

impl Cast {
    /// `seed` drives the random choice of unpinned scenes.
    #[must_use]
    pub fn new(library: Library, seed: u64) -> Self {
        Self { library, pins: Vec::new(), seed, quiet: None }
    }

    /// The scenes `milestone` picks from; none for anything else.
    #[must_use]
    pub fn pool(milestone: &str) -> &'static [&'static str] {
        POOLS.iter().chain(&TRUNK_POOLS).find(|(name, _)| *name == milestone).map_or(&[], |(_, pool)| *pool)
    }

    /// The quiet scenes, one of which shows when nothing has happened for a while.
    #[must_use]
    pub fn quiet_pool() -> &'static [&'static str] {
        &QUIET
    }

    /// Makes `name` its pool's scene from now on; a name in no pool is ignored.
    pub fn pin(&mut self, name: &str) {
        let pools = POOLS.iter().chain(&TRUNK_POOLS).map(|(_, pool)| *pool).chain([&QUIET[..]]);
        let Some(pool) = pools.into_iter().find(|pool| pool.contains(&name)) else { return };
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

    /// A quiet scene as of `play_ms`: the one picked before, until it has
    /// shown for five minutes, when a different one takes over; a pinned one
    /// holds.
    pub fn quiet(&mut self, play_ms: u64) -> &'static dyn Scene {
        if let Some(pinned) = self.pins.iter().copied().find(|pinned| QUIET.contains(pinned)) {
            return self.named(pinned);
        }
        let name = match self.quiet {
            Some((name, since)) if play_ms.saturating_sub(since) < QUIET_TURN_MS => name,
            showing => self.next_quiet(showing.map(|(name, _)| name), play_ms),
        };
        self.named(name)
    }

    /// Ends the quiet spell, so the next one picks its scene afresh.
    pub fn wake(&mut self) {
        self.quiet = None;
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

    /// A quiet scene other than `showing`, shown from `play_ms`.
    fn next_quiet(&mut self, showing: Option<&'static str>, play_ms: u64) -> &'static str {
        let others: Vec<&'static str> = QUIET.iter().copied().filter(|name| Some(*name) != showing).collect();
        let name = self.random(&others);
        self.quiet = Some((name, play_ms));
        name
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
