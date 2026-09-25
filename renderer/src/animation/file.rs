use std::collections::BTreeMap;

use serde::Deserialize;

use super::style::Style;
use super::{Frame, Playback, StyledLine};

const RESET: &str = "\u{1b}[0m";
const DEFAULT_KEY: char = ' ';

/// `renderer/animations/<name>.json`, as written by `renderer/tools/convert_animations.rb`.
#[derive(Deserialize)]
pub struct AnimationFile {
    pub name: String,
    #[serde(flatten)]
    pub playback: Playback,
    #[serde(flatten)]
    pub art: Art,
}

#[derive(Deserialize)]
pub struct Art {
    styles: BTreeMap<char, Style>,
    frames: Vec<FrameFile>,
}

#[derive(Deserialize)]
struct FrameFile {
    text: Vec<String>,
    style: Vec<String>,
}

impl Art {
    pub fn frames(&self) -> Result<Vec<Frame>, String> {
        self.frames.iter().map(|frame| self.frame(frame)).collect()
    }

    fn frame(&self, frame: &FrameFile) -> Result<Frame, String> {
        if frame.text.len() != frame.style.len() {
            return Err(format!("{} lines of text but {} of style", frame.text.len(), frame.style.len()));
        }
        frame.text.iter().zip(&frame.style).map(|(text, mask)| self.line(text, mask)).collect()
    }

    fn line(&self, text: &str, mask: &str) -> Result<StyledLine, String> {
        let width = text.chars().count();
        if mask.chars().count() != width {
            return Err(format!("style mask {mask:?} does not match {text:?}"));
        }
        let mut ansi = LineWriter::default();
        text.chars().zip(mask.chars()).try_for_each(|(ch, key)| ansi.push(ch, key, &self.styles))?;
        Ok(StyledLine::new(ansi.finish(), width))
    }
}

struct LineWriter {
    ansi: String,
    key: char,
}

impl Default for LineWriter {
    fn default() -> Self {
        Self { ansi: String::new(), key: DEFAULT_KEY }
    }
}

impl LineWriter {
    fn push(&mut self, ch: char, key: char, styles: &BTreeMap<char, Style>) -> Result<(), String> {
        if key != self.key {
            self.ansi.push_str(&escape(key, styles)?);
            self.key = key;
        }
        self.ansi.push(ch);
        Ok(())
    }

    fn finish(mut self) -> String {
        if self.key != DEFAULT_KEY {
            self.ansi.push_str(RESET);
        }
        self.ansi
    }
}

fn escape(key: char, styles: &BTreeMap<char, Style>) -> Result<String, String> {
    if key == DEFAULT_KEY {
        return Ok(RESET.to_string());
    }
    styles.get(&key).map(Style::sgr).ok_or_else(|| format!("no style {key:?}"))
}
