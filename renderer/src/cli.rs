//! Command-line options.

use std::path::PathBuf;

use crate::art::output::Depth;

/// Exit status for a command line the renderer cannot act on.
pub const EXIT_USAGE: i32 = 64;

/// What the command line asked for.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Options {
    pub headless: bool,
    pub size: (u16, u16),
    pub paths: Paths,
    pub depth: Option<Depth>,
}

/// The files and directories named on the command line.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Paths {
    pub scenario: Option<PathBuf>,
    pub out: Option<PathBuf>,
    pub tty: Option<PathBuf>,
}

/// A headless run: replay `scenario` on a `size` terminal in `depth`'s
/// colours, write into `out`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Headless {
    pub size: (u16, u16),
    pub depth: Depth,
    pub scenario: PathBuf,
    pub out: PathBuf,
}

impl Default for Options {
    fn default() -> Self {
        Self { headless: false, size: (80, 24), paths: Paths::default(), depth: None }
    }
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
            let value = if flag == "--headless" { Some(String::new()) } else { args.next() };
            options.set(&flag, value.ok_or_else(|| format!("{flag} needs a value"))?)?;
        }
        Ok(options)
    }

    /// The colours to draw in: `--colours`, else 24-bit when `colorterm` (the
    /// `COLORTERM` variable) says the terminal has them, else xterm's 256.
    #[must_use]
    pub fn depth(&self, colorterm: Option<&str>) -> Depth {
        let true_colour = matches!(colorterm, Some("truecolor" | "24bit"));
        self.depth.unwrap_or(if true_colour { Depth::TrueColour } else { Depth::Xterm256 })
    }

    /// The terminal a live session draws on: `--tty <path>`, else `/dev/tty`.
    #[must_use]
    pub fn tty(&self) -> PathBuf {
        self.paths.tty.clone().unwrap_or_else(|| PathBuf::from("/dev/tty"))
    }

    /// The headless run asked for, if `--headless` was given.
    ///
    /// # Errors
    /// When `--headless` lacks `--scenario` or `--out`.
    pub fn headless(&self) -> Result<Option<Headless>, String> {
        if !self.headless {
            return Ok(None);
        }
        let need = |path: &Option<PathBuf>, flag: &str| path.clone().ok_or_else(|| format!("--headless needs {flag}"));
        let (scenario, out) = (need(&self.paths.scenario, "--scenario")?, need(&self.paths.out, "--out")?);
        Ok(Some(Headless { size: self.size, depth: self.depth.unwrap_or(Depth::TrueColour), scenario, out }))
    }

    fn set(&mut self, flag: &str, value: String) -> Result<(), String> {
        match flag {
            "--headless" => self.headless = true,
            "--cols" | "--rows" => self.set_size(flag, &value)?,
            "--colours" => self.depth = Some(depth(&value)?),
            "--scenario" | "--out" | "--tty" => self.paths.set(flag, value),
            _ => return Err(format!("unknown option {flag}")),
        }
        Ok(())
    }

    fn set_size(&mut self, flag: &str, value: &str) -> Result<(), String> {
        let number = value.parse::<u16>().ok().filter(|n| *n > 0).ok_or_else(|| format!("{flag} {value}?"))?;
        if flag == "--cols" { self.size.0 = number } else { self.size.1 = number }
        Ok(())
    }
}

impl Paths {
    fn set(&mut self, flag: &str, value: String) {
        let path = Some(PathBuf::from(value));
        match flag {
            "--scenario" => self.scenario = path,
            "--tty" => self.tty = path,
            _ => self.out = path,
        }
    }
}

fn depth(value: &str) -> Result<Depth, String> {
    match value {
        "24bit" => Ok(Depth::TrueColour),
        "256" => Ok(Depth::Xterm256),
        _ => Err(format!("--colours {value}? (24bit or 256)")),
    }
}
