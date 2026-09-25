//! The contact sheet: every frame at half size, left to right, top to bottom,
//! in a square-ish grid.

use super::raster::Image;

/// All `frames` tiled at half size.
#[must_use]
pub fn contact_sheet(frames: &[Image]) -> Image {
    let (across, tile) = (tiles_across(frames.len()), tile_size(frames));
    let mut sheet = Image::blank(across * tile.0, frames.len().div_ceil(across) * tile.1);
    for (i, frame) in frames.iter().enumerate() {
        place(&mut sheet, frame, (i % across * tile.0, i / across * tile.1));
    }
    sheet
}

fn tiles_across(count: usize) -> usize {
    (1..=count).find(|n| n * n >= count).unwrap_or(1)
}

fn tile_size(frames: &[Image]) -> (usize, usize) {
    let widest = frames.iter().map(|f| f.width).max().unwrap_or(0);
    let tallest = frames.iter().map(|f| f.height).max().unwrap_or(0);
    (widest / 2, tallest / 2)
}

fn place(sheet: &mut Image, frame: &Image, (left, top): (usize, usize)) {
    for y in 0..frame.height / 2 {
        for x in 0..frame.width / 2 {
            sheet.set(left + x, top + y, frame.pixel(x * 2, y * 2));
        }
    }
}
