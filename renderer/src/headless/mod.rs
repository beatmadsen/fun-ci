//! Headless mode (`--headless`): replay a scenario and write what it drew for
//! machines (frames.jsonl, stats.json), vision models (frames/NNNN.png,
//! sheet.png) and people (frames.cast).

mod cast;
pub mod palette;
pub mod raster;
pub mod sheet;
pub mod stats;

use std::fs;
use std::path::{Path, PathBuf};

use serde::Serialize;

pub use raster::CELL;

use crate::animation::Library;
use crate::cli::Headless;
use crate::grid::{Emulator, Grid};
use crate::replay::{TickFrame, replay};
use crate::scenario;
use raster::Image;

/// Replays `headless.scenario` and writes every output into `headless.out`.
///
/// # Errors
/// When the scenario cannot be read or an output cannot be written.
pub fn run(headless: &Headless, library: &Library) -> Result<(), String> {
    let frames = replay(&scenario::load(&headless.scenario)?, library, headless.size, headless.depth);
    let grids = emulate(&frames);
    let images: Vec<Image> = grids.iter().map(raster::render).collect();
    let out = Output::create(&headless.out)?;
    out.write_all(&frames, &grids, &images)
}

/// Each frame's screen after feeding the frames in order to one terminal.
#[must_use]
pub fn emulate(frames: &[TickFrame]) -> Vec<Grid> {
    let mut emulator = Emulator::new(frames.first().map_or((80, 24), |frame| frame.size));
    let mut feed = |frame: &TickFrame| {
        emulator.feed(frame.size, &frame.bytes);
        emulator.grid()
    };
    frames.iter().map(&mut feed).collect()
}

#[derive(Serialize)]
struct FrameLine<'g> {
    frame: usize,
    #[serde(flatten)]
    grid: &'g Grid,
}

struct Output {
    dir: PathBuf,
}

impl Output {
    fn create(dir: &Path) -> Result<Self, String> {
        fs::create_dir_all(dir.join("frames")).map_err(|e| format!("{}: {e}", dir.display()))?;
        Ok(Self { dir: dir.to_path_buf() })
    }

    fn write_all(&self, frames: &[TickFrame], grids: &[Grid], images: &[Image]) -> Result<(), String> {
        self.write("frames.jsonl", frames_jsonl(grids)?.as_bytes())?;
        self.write_pngs(images)?;
        self.write("sheet.png", &png(&sheet::contact_sheet(images))?)?;
        self.write("frames.cast", cast::asciicast(frames).as_bytes())?;
        let stats = serde_json::to_string_pretty(&stats::stats(frames, grids, images)).map_err(|e| e.to_string())?;
        self.write("stats.json", stats.as_bytes())
    }

    fn write_pngs(&self, images: &[Image]) -> Result<(), String> {
        for (i, image) in images.iter().enumerate() {
            self.write(&format!("frames/{:04}.png", i + 1), &png(image)?)?;
        }
        Ok(())
    }

    fn write(&self, name: &str, bytes: &[u8]) -> Result<(), String> {
        let path = self.dir.join(name);
        fs::write(&path, bytes).map_err(|e| format!("{}: {e}", path.display()))
    }
}

fn frames_jsonl(grids: &[Grid]) -> Result<String, String> {
    let line = |(i, grid)| serde_json::to_string(&FrameLine { frame: i + 1, grid }).map_err(|e| e.to_string());
    let lines: Vec<String> = grids.iter().enumerate().map(line).collect::<Result<_, _>>()?;
    Ok(lines.join("\n") + "\n")
}

fn png(image: &Image) -> Result<Vec<u8>, String> {
    encode(image).map_err(|e| e.to_string())
}

fn encode(image: &Image) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let (width, height) = (u32::try_from(image.width)?, u32::try_from(image.height)?);
    let mut bytes = Vec::new();
    let mut encoder = png::Encoder::new(&mut bytes, width, height);
    encoder.set_color(png::ColorType::Rgb);
    encoder.set_depth(png::BitDepth::Eight);
    encoder.write_header()?.write_image_data(&image.pixels)?;
    Ok(bytes)
}
