//! The fireplace quiet scene: a storm outside lights the room now and then.

use fun_ci_renderer::animation::{Library, Scene};
use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::float;

/// The room's mean brightness `t_ms` into the scene.
fn brightness(scene: &dyn Scene, t_ms: u64) -> f64 {
    let mut canvas = Canvas::new(320, 112);
    scene.paint(&mut canvas, t_ms);
    let pixels = (0..112).flat_map(|y| (0..320).map(move |x| (x, y)));
    pixels.map(|(x, y)| canvas.get(x, y).iter().sum::<f64>()).sum::<f64>() / float(320 * 112)
}

#[test]
fn should_light_the_room_with_lightning_now_and_then() {
    let scene = Library::builtin().get("fireplace").unwrap();
    let mut levels: Vec<f64> = (0..300).map(|step| brightness(scene, step * 50)).collect();
    levels.sort_by(f64::total_cmp);
    let (median, brightest) = (levels[150], levels[299]);
    assert!(brightest > median * 1.4, "brightest {brightest:.3} vs median {median:.3}");
}
