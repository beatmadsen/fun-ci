//! Header animations as scenes: pictures painted afresh for each frame from
//! the time since the scene started, at whatever size the header has.

mod library;

use std::fmt::Debug;

use crate::art::canvas::Canvas;

pub use library::Library;

/// Something the header can show.
pub trait Scene: Debug + Sync {
    /// The name events and scenarios choose it by.
    fn name(&self) -> &'static str;

    /// How long it plays, in milliseconds; none for a scene that loops.
    fn length_ms(&self) -> Option<u64>;

    /// Paints the scene as it is `t_ms` after it started over the whole canvas.
    fn paint(&self, canvas: &mut Canvas, t_ms: u64);

    /// How often it needs drawing when nothing else on screen moves, in
    /// milliseconds; once a second for a scene that keeps still.
    fn frame_ms(&self) -> u64 {
        1000
    }
}

/// A black header, for a name the library lacks.
#[derive(Debug)]
pub struct Blank(pub &'static str);

impl Scene for Blank {
    fn name(&self) -> &'static str {
        self.0
    }

    fn length_ms(&self) -> Option<u64> {
        None
    }

    fn paint(&self, _canvas: &mut Canvas, _t_ms: u64) {}
}
