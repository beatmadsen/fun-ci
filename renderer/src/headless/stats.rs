//! stats.json: measurements beside the frames that explain what looks wrong.

use std::collections::BTreeMap;

use serde::Serialize;

use super::palette::{hue_sector, luminance, visible_colour};
use super::raster::Image;
use crate::grid::{Cell, Colour, Grid};
use crate::replay::TickFrame;

const DARK: u8 = 64;

/// Per frame measurements, and how many frames each header animation showed.
#[derive(Debug, Serialize)]
pub struct Stats {
    pub frames: Vec<FrameStats>,
    pub animations: BTreeMap<String, usize>,
}

#[derive(Debug, Serialize)]
pub struct FrameStats {
    pub frame: usize,
    #[serde(flatten)]
    pub volume: Volume,
    #[serde(flatten)]
    pub colour: ColourStats,
}

/// How much a frame wrote and changed.
#[derive(Debug, Serialize)]
pub struct Volume {
    pub bytes: usize,
    pub longest_row: usize,
    pub cells_changed: usize,
}

/// How a frame's colours are spread: pixel luminance in eight buckets of 32,
/// the share of cells whose visible colour has luminance under 64, and how
/// many 30-degree hue sectors the glyphs' colours cover.
#[derive(Debug, Serialize)]
pub struct ColourStats {
    pub luminance_histogram: [usize; 8],
    pub dark_cell_share: f64,
    pub hue_spread: usize,
}

/// Measures each frame (`frames`, their `grids` and `images` in step).
#[must_use]
pub fn stats(frames: &[TickFrame], grids: &[Grid], images: &[Image]) -> Stats {
    let previous = std::iter::once(None).chain(grids.iter().map(Some));
    let measured = frames.iter().zip(grids).zip(previous).zip(images).enumerate();
    let measure = |(i, (((f, g), p), img))| FrameStats { frame: i + 1, volume: volume(f, g, p), colour: colour(g, img) };
    Stats { frames: measured.map(measure).collect(), animations: shown(frames) }
}

fn volume(frame: &TickFrame, grid: &Grid, previous: Option<&Grid>) -> Volume {
    Volume { bytes: frame.bytes.len(), longest_row: longest_row(grid), cells_changed: changed(grid, previous) }
}

fn colour(grid: &Grid, image: &Image) -> ColourStats {
    ColourStats { luminance_histogram: histogram(image), dark_cell_share: dark_share(grid), hue_spread: hues(grid) }
}

fn shown(frames: &[TickFrame]) -> BTreeMap<String, usize> {
    let mut counts = BTreeMap::new();
    for frame in frames {
        *counts.entry(frame.showing.clone()).or_insert(0) += 1;
    }
    counts
}

fn longest_row(grid: &Grid) -> usize {
    let length = |row: &Vec<Cell>| row.iter().rposition(|c| !c.text.trim().is_empty()).map_or(0, |i| i + 1);
    grid.cells.iter().map(length).max().unwrap_or(0)
}

fn changed(grid: &Grid, previous: Option<&Grid>) -> usize {
    let cells = grid.cells.iter().flatten();
    match previous.filter(|p| (p.cols, p.rows) == (grid.cols, grid.rows)) {
        Some(previous) => cells.zip(previous.cells.iter().flatten()).filter(|(a, b)| a != b).count(),
        None => cells.filter(|cell| !is_blank(cell)).count(),
    }
}

fn is_blank(cell: &Cell) -> bool {
    cell.text.trim().is_empty() && cell.bg == Colour::Default && cell.attrs.is_empty()
}

fn histogram(image: &Image) -> [usize; 8] {
    let mut buckets = [0; 8];
    for rgb in image.pixels.as_chunks::<3>().0 {
        buckets[usize::from(luminance(*rgb) / 32)] += 1;
    }
    buckets
}

fn dark_share(grid: &Grid) -> f64 {
    let cells: Vec<&Cell> = grid.cells.iter().flatten().collect();
    let dark = cells.iter().filter(|cell| luminance(visible_colour(cell)) < DARK).count();
    ratio(dark, cells.len())
}

fn hues(grid: &Grid) -> usize {
    let glyphs = grid.cells.iter().flatten().filter(|cell| !cell.text.trim().is_empty());
    let sectors: std::collections::BTreeSet<u8> = glyphs.filter_map(|cell| hue_sector(visible_colour(cell))).collect();
    sectors.len()
}

fn ratio(part: usize, whole: usize) -> f64 {
    let as_f64 = |n: usize| f64::from(u32::try_from(n).unwrap_or(u32::MAX));
    if whole == 0 { 0.0 } else { as_f64(part) / as_f64(whole) }
}
