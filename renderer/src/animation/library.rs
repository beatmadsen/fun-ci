use std::collections::BTreeMap;

use super::Scene;

/// Every scene the renderer can show, by name.
#[derive(Debug, Clone, Default)]
pub struct Library {
    scenes: BTreeMap<&'static str, &'static dyn Scene>,
}

impl Library {
    /// The scenes built into the renderer.
    #[must_use]
    pub fn builtin() -> Self {
        let mut library = Self::default();
        for scene in crate::scenes::ALL {
            library.insert(scene);
        }
        library
    }

    #[must_use]
    pub fn get(&self, name: &str) -> Option<&'static dyn Scene> {
        self.scenes.get(name).copied()
    }

    #[must_use]
    pub fn names(&self) -> Vec<&str> {
        self.scenes.keys().copied().collect()
    }

    /// Adds `scene`, replacing any of the same name.
    pub fn insert(&mut self, scene: &'static dyn Scene) {
        self.scenes.insert(scene.name(), scene);
    }
}
