//! Deterministic randomness: a number per (index, salt), and smooth value
//! noise over the plane with its fractal sum.

/// A number in 0.0..1.0 fixed by `index` and `salt`.
#[must_use]
pub fn dice(index: u64, salt: u64) -> f64 {
    unit(mixed(index.wrapping_mul(0x9E37_79B9_7F4A_7C15) ^ salt.wrapping_mul(0xC2B2_AE3D_27D4_EB4F)))
}

/// Smooth noise in 0.0..1.0: random at whole coordinates, eased between.
#[must_use]
pub fn value(x: f64, y: f64, salt: u64) -> f64 {
    let (x0, y0) = (x.floor(), y.floor());
    let (fx, fy) = (ease(x - x0), ease(y - y0));
    let corner = |dx: f64, dy: f64| lattice(x0 + dx, y0 + dy, salt);
    let top = corner(0.0, 0.0) + (corner(1.0, 0.0) - corner(0.0, 0.0)) * fx;
    let bottom = corner(0.0, 1.0) + (corner(1.0, 1.0) - corner(0.0, 1.0)) * fx;
    top + (bottom - top) * fy
}

/// Four octaves of `value`, each twice the frequency and half the weight;
/// the weights sum to 1, so it stays in 0.0..1.0.
#[must_use]
pub fn fbm(x: f64, y: f64, salt: u64) -> f64 {
    let octave = |i: u64, weight: f64, frequency: f64| weight * value(x * frequency, y * frequency, salt + i);
    octave(0, 0.5333, 1.0) + octave(1, 0.2667, 2.0) + octave(2, 0.1333, 4.0) + octave(3, 0.0667, 8.0)
}

fn lattice(x: f64, y: f64, salt: u64) -> f64 {
    dice(x.to_bits(), y.to_bits() ^ salt.rotate_left(17))
}

fn ease(t: f64) -> f64 {
    t * t * (3.0 - 2.0 * t)
}

fn mixed(mut z: u64) -> u64 {
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

fn unit(bits: u64) -> f64 {
    f64::from(u32::try_from(bits >> 32).unwrap_or(u32::MAX)) / 4_294_967_296.0
}
