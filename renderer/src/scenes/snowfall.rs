//! Quiet: snowfall. Snow drifts down in three depths over dark pines with
//! snow on their boughs, on a soft slope under a clouded night, the moon a
//! pale smudge behind the clouds.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, haze};
use crate::art::noise::{dice, fbm};
use crate::art::{Shade, add, float, mix, scale, seconds, smoothstep};

const SKY: Shade = [0.05, 0.06, 0.1];
const CLOUD: Shade = [0.1, 0.11, 0.15];
const SNOW: Shade = [0.34, 0.37, 0.44];
const PINE: Shade = [0.02, 0.06, 0.045];
const FLAKES: u64 = 90;
const PINES: u64 = 9;

#[derive(Debug)]
pub struct Snowfall;

impl Scene for Snowfall {
    fn name(&self) -> &'static str {
        "snowfall"
    }

    fn length_ms(&self) -> Option<u64> {
        None
    }

    fn frame_ms(&self) -> u64 {
        250
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let (width, height) = canvas.size();
        canvas.map(|x, y, _| backdrop(x, y / height, t));
        glow(canvas, (width * 0.72, 22.0), 14.0, [0.06, 0.06, 0.07]);
        (0..PINES).for_each(|i| pine(canvas, i));
        canvas.map(|x, y, pixel| if y > ground(x, height) { add(scale(SNOW, 0.85 + 0.15 * fbm(x / 30.0, y / 10.0, 141)), [0.0; 3]) } else { pixel });
        (0..FLAKES).for_each(|i| flake(canvas, i, t));
    }
}

/// The clouded night at (x, `k` down): slow-drifting cloud over a dark sky.
fn backdrop(x: f64, k: f64, t: f64) -> Shade {
    let cloud = smoothstep(0.4, 0.75, fbm(x / 90.0 + t * 0.01, k * 3.0, 142));
    mix(SKY, CLOUD, cloud * (1.0 - k * 0.5))
}

/// Where the snow-covered ground starts at `x`: a soft, rolling slope.
fn ground(x: f64, height: f64) -> f64 {
    height * (0.82 - 0.12 * fbm(x / 60.0, 0.3, 143))
}

/// Pine `i`: a dark tapering tree standing on the slope, snow on its boughs.
fn pine(canvas: &mut Canvas, i: u64) {
    let (width, height) = canvas.size();
    let x = (float(usize::try_from(i).unwrap_or(0)) + 0.5 + 0.6 * (dice(i, 144) - 0.5)) / float(9) * width;
    let (base, tall) = (ground(x, height) + 2.0, 26.0 + 22.0 * dice(i, 145));
    for tier in 0..5_u32 {
        let k = f64::from(tier) / 5.0;
        let (y, half) = (base - k * tall, (1.0 - k) * tall * 0.32 + 2.0);
        haze(canvas, (x, y - 3.0), half * 0.8, (PINE, 1.0));
        haze(canvas, (x, y - 3.0 - half * 0.5), half * 0.4, (scale(SNOW, 1.1), 0.85));
    }
}

/// Flake `i`: drifting down at its depth's pace, swaying, looping from the top.
fn flake(canvas: &mut Canvas, i: u64, t: f64) {
    let (width, height) = canvas.size();
    let depth = 0.4 + 0.6 * dice(i, 146);
    let fall = (t * (6.0 + 10.0 * depth) + dice(i, 147) * height) % (height + 6.0) - 3.0;
    let x = (dice(i, 148) * width + 5.0 * (t * 0.6 + dice(i, 149) * 6.0).sine() * depth).rem_euclid(width);
    glow(canvas, (x, fall), 0.5 + 0.7 * depth, scale([0.8, 0.85, 0.95], 0.35 + 0.55 * depth));
}
