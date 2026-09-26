//! Maths that gives the same answer on every machine. The standard library's
//! `sin`, `exp` and the like call the platform's maths library, which rounds
//! differently on macOS and Linux, and a last-bit difference can tip a cell
//! from one glyph or colour to another; `libm` is plain Rust, so a scene paints
//! the same pixels wherever it runs. Art and scene code uses these instead.

/// Transcendental functions on `f64` that are identical on every platform.
pub trait Portable {
    #[must_use]
    fn sine(self) -> f64;
    #[must_use]
    fn cosine(self) -> f64;
    #[must_use]
    fn exponential(self) -> f64;
    #[must_use]
    fn power(self, exponent: f64) -> f64;
    #[must_use]
    fn hypotenuse(self, other: f64) -> f64;
    #[must_use]
    fn arctangent2(self, x: f64) -> f64;
}

impl Portable for f64 {
    fn sine(self) -> f64 {
        libm::sin(self)
    }

    fn cosine(self) -> f64 {
        libm::cos(self)
    }

    fn exponential(self) -> f64 {
        libm::exp(self)
    }

    fn power(self, exponent: f64) -> f64 {
        libm::pow(self, exponent)
    }

    fn hypotenuse(self, other: f64) -> f64 {
        libm::hypot(self, other)
    }

    /// The angle of (`x`, `self`) from the x axis, as `f64::atan2` gives it.
    fn arctangent2(self, x: f64) -> f64 {
        libm::atan2(self, x)
    }
}
