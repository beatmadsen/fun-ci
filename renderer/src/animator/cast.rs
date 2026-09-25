//! Which animation plays for which occasion. A scenario (or a test) may pin
//! the choice; otherwise success animations are picked at random.

use crate::animation::{Animation, Library};

const FAILURES: [&str; 1] = ["explosion"];
const SUCCESSES: [&str; 5] = ["success", "celebrate", "flash", "leprechauns", "yay"];

#[derive(Debug, Clone, Default)]
struct Pins {
    failure: Option<String>,
    success: Option<String>,
}

/// The animation library plus the current choices.
#[derive(Debug, Clone)]
pub struct Cast {
    library: Library,
    pins: Pins,
    seed: u64,
}

impl Cast {
    /// `seed` drives the random choice of unpinned animations.
    #[must_use]
    pub fn new(library: Library, seed: u64) -> Self {
        Self { library, pins: Pins::default(), seed }
    }

    /// Makes `name` the failure or success animation from now on; a name that
    /// is neither is ignored.
    pub fn pin(&mut self, name: &str) {
        if FAILURES.contains(&name) {
            self.pins.failure = Some(name.to_string());
        } else if SUCCESSES.contains(&name) {
            self.pins.success = Some(name.to_string());
        }
    }

    #[must_use]
    pub fn idle(&self) -> Animation {
        self.named("idle")
    }

    #[must_use]
    pub fn running(&self) -> Animation {
        self.named("running")
    }

    pub fn failure(&mut self) -> Animation {
        let name = self.pins.failure.clone().unwrap_or_else(|| self.random(&FAILURES));
        self.named(&name)
    }

    pub fn success(&mut self) -> Animation {
        let name = self.pins.success.clone().unwrap_or_else(|| self.random(&SUCCESSES));
        self.named(&name)
    }

    fn random(&mut self, names: &[&str]) -> String {
        self.seed ^= self.seed << 13;
        self.seed ^= self.seed >> 7;
        self.seed ^= self.seed << 17;
        let index = usize::try_from(self.seed % names.len() as u64).unwrap_or_default();
        names[index].to_string()
    }

    fn named(&self, name: &str) -> Animation {
        self.library.get(name).cloned().unwrap_or_else(|| Animation::blank(name))
    }
}
