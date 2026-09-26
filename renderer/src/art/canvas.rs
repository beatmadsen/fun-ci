//! Pixels to paint light on.

use super::math::Portable;
use super::{Shade, float, mix};

/// Where the tone curve starts to bend: light below it shows as it is.
const KNEE: f64 = 0.75;

/// A grid of pixels, black to start with.
#[derive(Debug, Clone, PartialEq)]
pub struct Canvas {
    width: usize,
    height: usize,
    pixels: Vec<Shade>,
}

impl Canvas {
    #[must_use]
    pub fn new(width: usize, height: usize) -> Self {
        Self { width, height, pixels: vec![[0.0; 3]; width * height] }
    }

    #[must_use]
    pub fn width(&self) -> usize {
        self.width
    }

    #[must_use]
    pub fn height(&self) -> usize {
        self.height
    }

    /// The canvas size as floats, (width, height).
    #[must_use]
    pub fn size(&self) -> (f64, f64) {
        (float(self.width), float(self.height))
    }

    /// The pixel at (`x`, `y`).
    #[must_use]
    pub fn get(&self, x: usize, y: usize) -> Shade {
        self.pixels[y * self.width + x]
    }

    /// Replaces every pixel with `shade(x, y, pixel)`, (x, y) its centre.
    pub fn map(&mut self, shade: impl Fn(f64, f64, Shade) -> Shade) {
        let width = self.width;
        for (i, pixel) in self.pixels.iter_mut().enumerate() {
            *pixel = shade(float(i % width) + 0.5, float(i / width) + 0.5, *pixel);
        }
    }

    /// Adds `light` to the pixel at (`x`, `y`), if it is on the canvas.
    pub fn add(&mut self, (x, y): (usize, usize), light: Shade) {
        if let Some(pixel) = self.pixel_mut(x, y) {
            *pixel = [pixel[0] + light[0], pixel[1] + light[1], pixel[2] + light[2]];
        }
    }

    /// Covers the pixel at (`x`, `y`) with `shade`, `alpha` of the way.
    pub fn cover(&mut self, (x, y): (usize, usize), shade: Shade, alpha: f64) {
        if let Some(pixel) = self.pixel_mut(x, y) {
            *pixel = mix(*pixel, shade, alpha.clamp(0.0, 1.0));
        }
    }

    /// Brings light above 1.0 into range: each channel bends softly towards
    /// 1.0 above the knee, and what a channel had over 1.0 spills into the
    /// others, so the brightest light turns white.
    pub fn tone(&mut self) {
        self.pixels.iter_mut().for_each(|pixel| *pixel = toned(*pixel));
    }

    fn pixel_mut(&mut self, x: usize, y: usize) -> Option<&mut Shade> {
        (x < self.width && y < self.height).then(|| &mut self.pixels[y * self.width + x])
    }
}

fn toned(pixel: Shade) -> Shade {
    let spill = pixel.iter().map(|channel| (channel - 1.0).max(0.0)).sum::<f64>() * 0.35;
    pixel.map(|channel| shoulder(channel + spill))
}

fn shoulder(channel: f64) -> f64 {
    if channel <= KNEE { channel.max(0.0) } else { KNEE + (1.0 - KNEE) * (1.0 - (-(channel - KNEE) / (1.0 - KNEE)).exponential()) }
}
