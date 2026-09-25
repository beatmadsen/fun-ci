//! Command-line options.

use std::path::PathBuf;

use crate::animation::Library;

/// Exit status for a command line the renderer cannot act on.
pub const EXIT_USAGE: i32 = 64;

/// What the command line asked for.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Options {
    pub animations: Option<PathBuf>,
}

impl Options {
    /// Reads the arguments after the program name.
    ///
    /// # Errors
    /// On an unknown flag or a flag missing its value.
    pub fn parse(args: impl IntoIterator<Item = String>) -> Result<Self, String> {
        let mut options = Self::default();
        let mut args = args.into_iter();
        while let Some(flag) = args.next() {
            let value = args.next().ok_or_else(|| format!("{flag} needs a value"))?;
            options.set(&flag, value)?;
        }
        Ok(options)
    }

    fn set(&mut self, flag: &str, value: String) -> Result<(), String> {
        match flag {
            "--animations" => self.animations = Some(PathBuf::from(value)),
            _ => return Err(format!("unknown option {flag}")),
        }
        Ok(())
    }

    /// The embedded animations, replaced by name from `--animations <dir>`.
    ///
    /// # Errors
    /// When the directory or a file in it cannot be loaded.
    pub fn library(&self) -> Result<Library, String> {
        let mut library = Library::builtin();
        if let Some(dir) = &self.animations {
            library.load_dir(dir)?;
        }
        Ok(library)
    }
}
