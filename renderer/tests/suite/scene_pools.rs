//! AT-7.3: every milestone has its own pool of scenes, so a scene tells the
//! viewer which milestone it stands for, and the scenes grow along the path.

use fun_ci_renderer::animation::{Library, Scene};
use fun_ci_renderer::animator::{Cast, MILESTONES};
use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::float;

const SUCCESSES: [&str; 4] = ["lint_passed", "build_passed", "fast_passed", "run_passed"];

fn pool(milestone: &str) -> &'static [&'static str] {
    Cast::pool(milestone)
}

fn lengths(milestones: &[&str]) -> Vec<u64> {
    let library = Library::builtin();
    let names = milestones.iter().flat_map(|milestone| pool(milestone));
    names.map(|name| library.get(name).and_then(Scene::length_ms).unwrap()).collect()
}

/// The largest share of the header's pixels `name` lights at any moment of its length.
fn most_lit(name: &str) -> f64 {
    let scene = Library::builtin().get(name).unwrap();
    (0..scene.length_ms().unwrap()).step_by(100).map(|t_ms| lit_share(scene, t_ms)).fold(0.0, f64::max)
}

fn lit_share(scene: &dyn Scene, t_ms: u64) -> f64 {
    let mut canvas = Canvas::new(320, 112);
    scene.paint(&mut canvas, t_ms);
    canvas.tone();
    let pixels = (0..112).flat_map(|y| (0..320).map(move |x| (x, y)));
    let lit = pixels.filter(|(x, y)| canvas.get(*x, *y).iter().sum::<f64>() > 0.3).count();
    float(lit) / float(320 * 112)
}

#[test]
fn should_give_every_success_milestone_at_least_two_scenes() {
    assert!(SUCCESSES.iter().all(|milestone| pool(milestone).len() >= 2));
}

#[test]
fn should_share_no_scene_between_pools() {
    let mut names: Vec<&str> = MILESTONES.iter().flat_map(|milestone| pool(milestone).iter().copied()).collect();
    let count = names.len();
    names.sort_unstable();
    names.dedup();
    assert_eq!(names.len(), count);
}

#[test]
fn should_find_every_pooled_scene_in_the_library() {
    let library = Library::builtin();
    assert!(MILESTONES.iter().flat_map(|milestone| pool(milestone)).all(|name| library.get(name).is_some()));
}

#[test]
fn should_play_lint_and_build_scenes_shorter_than_the_fast_suite_scenes() {
    let small = lengths(&["lint_passed", "build_passed"]);
    assert!(small.iter().max() < lengths(&["fast_passed"]).iter().min());
}

#[test]
fn should_play_fast_suite_scenes_shorter_than_the_scenes_of_a_passing_run() {
    assert!(lengths(&["fast_passed"]).iter().max() < lengths(&["run_passed"]).iter().min());
}

#[test]
fn should_light_less_than_half_the_header_in_a_lint_or_build_scene() {
    let small = [pool("lint_passed"), pool("build_passed")].concat();
    assert!(small.iter().all(|name| most_lit(name) < 0.5), "{:?}", small.iter().map(|n| most_lit(n)).collect::<Vec<_>>());
}

#[test]
fn should_light_less_of_the_header_in_lint_and_build_scenes_than_in_any_fast_suite_scene() {
    let most = |milestones: &[&str]| milestones.iter().flat_map(|m| pool(m)).map(|name| most_lit(name)).collect::<Vec<f64>>();
    let (small, fast) = (most(&["lint_passed", "build_passed"]), most(&["fast_passed"]));
    assert!(small.iter().copied().fold(0.0, f64::max) < fast.iter().copied().fold(1.0, f64::min), "{small:?} vs {fast:?}");
}

#[test]
fn should_pick_a_milestone_scene_from_its_own_pool() {
    let mut cast = Cast::new(Library::builtin(), 7);
    let picks: Vec<&str> = (0..20).map(|_| cast.for_milestone("build_passed").unwrap().name()).collect();
    assert!(picks.iter().all(|name| pool("build_passed").contains(name)));
}

#[test]
fn should_pin_the_pool_a_pinned_scene_belongs_to() {
    let mut cast = Cast::new(Library::builtin(), 7);
    cast.pin("yay");
    assert_eq!(cast.for_milestone("fast_passed").unwrap().name(), "yay");
}

#[test]
fn should_find_every_quiet_scene_in_the_library() {
    let library = Library::builtin();
    let missing: Vec<&&str> = Cast::quiet_pool().iter().filter(|name| library.get(name).is_none()).collect();
    assert!(missing.is_empty(), "missing {missing:?}");
}

#[test]
fn should_loop_every_quiet_scene() {
    let library = Library::builtin();
    assert!(Cast::quiet_pool().iter().all(|name| library.get(name).is_some_and(|scene| scene.length_ms().is_none())));
}

#[test]
fn should_keep_the_quiet_scenes_out_of_the_milestone_pools() {
    assert!(MILESTONES.iter().flat_map(|milestone| pool(milestone)).all(|name| !Cast::quiet_pool().contains(name)));
}

#[test]
fn should_offer_a_fireplace_among_the_quiet_scenes() {
    assert!(Cast::quiet_pool().contains(&"fireplace"), "{:?}", Cast::quiet_pool());
}

#[test]
fn should_offer_a_moonlit_island_among_the_quiet_scenes() {
    assert!(Cast::quiet_pool().contains(&"island"), "{:?}", Cast::quiet_pool());
}

#[test]
fn should_settle_a_spirit_level_when_lint_passes() {
    assert!(pool("lint_passed").contains(&"level"), "{:?}", pool("lint_passed"));
}

#[test]
fn should_ring_an_anvil_when_the_build_passes() {
    assert!(pool("build_passed").contains(&"anvil"), "{:?}", pool("build_passed"));
}

#[test]
fn should_jump_to_warp_speed_when_the_fast_suite_passes() {
    assert!(pool("fast_passed").contains(&"warp"), "{:?}", pool("fast_passed"));
}

#[test]
fn should_bring_up_the_sun_when_the_whole_run_passes() {
    assert!(pool("run_passed").contains(&"sunrise"), "{:?}", pool("run_passed"));
}

#[test]
fn should_shatter_like_glass_when_a_run_fails() {
    assert!(pool("run_failed").contains(&"shatter"), "{:?}", pool("run_failed"));
}
