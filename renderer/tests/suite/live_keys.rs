//! The live session tells Ruby about every key pressed, in order, and a
//! Ctrl-C is a key like any other (renderer-protocol.md).

use fun_ci_renderer::inputs::Input;
use serde_json::json;

use crate::support::live::{line, replies_after_ready};

#[test]
fn a_key_is_sent_to_ruby() {
    assert_eq!(replies_after_ready(vec![Input::Keys(b"j".to_vec())]), [json!({"t":"key","key":"j"})]);
}

#[test]
fn every_key_in_one_read_is_sent_in_order() {
    let replies = replies_after_ready(vec![Input::Keys(b"\x1b[Aq".to_vec())]);
    assert_eq!(replies, [json!({"t":"key","key":"up"}), json!({"t":"key","key":"q"})]);
}

fn after_ctrl_c_and_a_bad_line() -> Vec<serde_json::Value> {
    replies_after_ready(vec![Input::Keys(b"\x03".to_vec()), line("not json")])
}

#[test]
fn should_send_ctrl_c_to_ruby_as_a_key() {
    assert_eq!(after_ctrl_c_and_a_bad_line()[0], json!({"t":"key","key":"ctrl_c"}));
}

#[test]
fn should_keep_the_session_going_after_ctrl_c_so_the_next_line_is_answered() {
    assert_eq!(after_ctrl_c_and_a_bad_line().len(), 2);
}
