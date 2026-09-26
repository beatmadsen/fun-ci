//! Plain stand-in scenes of known length, and which of them the header shows
//! frame by frame, for the header's queue and resting tests.

use fun_ci_renderer::animation::{Library, Scene};
use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::protocol::{Inbound, parse};
use fun_ci_renderer::replay::replay;

/// A plain grey scene, `length_ms` long, or looping without one.
#[derive(Debug)]
pub struct Plain(pub &'static str, pub Option<u64>);

impl Scene for Plain {
    fn name(&self) -> &'static str {
        self.0
    }

    fn length_ms(&self) -> Option<u64> {
        self.1
    }

    fn paint(&self, canvas: &mut Canvas, _t_ms: u64) {
        canvas.map(|_, _, _| [0.2, 0.2, 0.2]);
    }
}

/// The name of the scene the header shows after each tick of `lines`, with only `scenes` in the library.
pub fn showing(scenes: &'static [Plain], lines: &[String]) -> Vec<String> {
    let mut library = Library::default();
    for scene in scenes {
        library.insert(scene);
    }
    let messages: Vec<Inbound> = lines.iter().map(|line| parse(line).unwrap()).collect();
    replay(&messages, &library, (80, 24), Depth::TrueColour).into_iter().map(|frame| frame.showing).collect()
}
