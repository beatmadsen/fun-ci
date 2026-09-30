//! A rainbow arcing over the sky from beyond the bottom of the picture,
//! drawn in from the left.

use crate::art::canvas::Canvas;
use crate::maths::Portable;
use crate::art::{Shade, hue, mix, smoothstep};

/// The rainbow, revealed left to right over the first second.
pub fn rainbow(canvas: &mut Canvas, t: f64) {
    let (width, height) = canvas.size();
    let (centre, radius) = ((width * 0.5, height * 1.35), (width * 0.45).min(150.0));
    let reveal = std::f64::consts::PI * (1.0 - smoothstep(0.1, 1.2, t));
    canvas.map(|x, y, pixel| {
        let band = (radius - (x - centre.0).hypotenuse(y - centre.1)) / 20.0;
        mix(pixel, spectrum(band), band_cover(band) * swept((centre.0 - x, centre.1 - y), reveal))
    });
}

/// How much of the rainbow shows `band` of the way across it: soft at both edges.
fn band_cover(band: f64) -> f64 {
    smoothstep(0.0, 0.08, band) * smoothstep(1.0, 0.92, band) * 0.6
}

/// 1.0 where the arc has been drawn: from the left round to the angle `reveal`.
fn swept((dx, dy): (f64, f64), reveal: f64) -> f64 {
    f64::from(u8::from(dy.arctangent2(dx) >= reveal))
}

/// Red at the outside edge of the band (0.0) round to violet at the inside (1.0).
fn spectrum(k: f64) -> Shade {
    hue(k.clamp(0.0, 1.0) * 0.78)
}
