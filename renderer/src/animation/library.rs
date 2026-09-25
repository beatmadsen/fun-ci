use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

use super::Animation;

const BUILTIN: [&str; 8] = [
    include_str!("../../animations/celebrate.json"),
    include_str!("../../animations/explosion.json"),
    include_str!("../../animations/flash.json"),
    include_str!("../../animations/idle.json"),
    include_str!("../../animations/leprechauns.json"),
    include_str!("../../animations/running.json"),
    include_str!("../../animations/success.json"),
    include_str!("../../animations/yay.json"),
];

/// Every animation the renderer can play, by name.
#[derive(Debug, Clone, Default)]
pub struct Library {
    animations: BTreeMap<String, Animation>,
}

impl Library {
    /// The animations compiled into the binary.
    ///
    /// # Panics
    /// When an embedded file is malformed; `tests/animations.rs` loads them all.
    #[must_use]
    pub fn builtin() -> Self {
        let mut library = Self::default();
        for json in BUILTIN {
            library.insert(Animation::from_json(json).expect("embedded animation"));
        }
        library
    }

    /// Adds every `*.json` in `dir`, replacing animations of the same name.
    ///
    /// # Errors
    /// When the directory cannot be read or a file in it is not an animation.
    pub fn load_dir(&mut self, dir: &Path) -> Result<(), String> {
        let entries = fs::read_dir(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
        for path in entries.filter_map(Result::ok).map(|e| e.path()) {
            if path.extension().is_some_and(|ext| ext == "json") {
                self.insert(load(&path)?);
            }
        }
        Ok(())
    }

    #[must_use]
    pub fn get(&self, name: &str) -> Option<&Animation> {
        self.animations.get(name)
    }

    #[must_use]
    pub fn names(&self) -> Vec<&str> {
        self.animations.keys().map(String::as_str).collect()
    }

    fn insert(&mut self, animation: Animation) {
        self.animations.insert(animation.name().to_string(), animation);
    }
}

fn load(path: &Path) -> Result<Animation, String> {
    let json = fs::read_to_string(path).map_err(|e| format!("{}: {e}", path.display()))?;
    Animation::from_json(&json).map_err(|e| format!("{}: {e}", path.display()))
}
