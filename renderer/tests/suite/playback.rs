//! Header animations play at their own `frame_ms`, whatever the draw rate.

use fun_ci_renderer::animation::{Animation, Library};
use fun_ci_renderer::grid::Grid;
use fun_ci_renderer::headless::emulate;
use fun_ci_renderer::protocol::{Inbound, parse};
use fun_ci_renderer::replay::replay;

use crate::support::boards::{TICK, board};

const TWO_FRAME_IDLE: &str = r#"{"name":"idle","frame_ms":200,"loop":true,"anchor":"header",
  "styles":{},"frames":[{"text":["@@"],"style":["  "]},{"text":["%%"],"style":["  "]}]}"#;

fn screen_after_ticks(ticks: usize) -> Grid {
    let mut library = Library::default();
    library.insert(Animation::from_json(TWO_FRAME_IDLE).unwrap());
    let lines = [vec![board(&[])], vec![TICK.to_string(); ticks]].concat();
    let messages: Vec<Inbound> = lines.iter().map(|line| parse(line).unwrap()).collect();
    emulate(&replay(&messages, &library, (80, 24))).pop().unwrap()
}

#[test]
fn a_header_frame_stays_up_for_its_frame_ms_across_quicker_draws() {
    assert!(screen_after_ticks(2).text().contains("@@"));
}

#[test]
fn a_header_frame_gives_way_once_its_frame_ms_has_passed() {
    assert!(screen_after_ticks(3).text().contains("%%"));
}
