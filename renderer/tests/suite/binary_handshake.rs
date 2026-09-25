//! The real binary refuses a version it does not speak, before it touches
//! the terminal (so it needs none).

use std::process::ExitStatus;

use crate::support::renderer::{Renderer, binary};

fn refused_hello() -> (ExitStatus, Vec<String>) {
    let mut renderer = Renderer::start(&mut binary());
    renderer.send(r#"{"t":"hello","v":9}"#);
    renderer.close_input();
    (renderer.wait(), renderer.rest())
}

#[test]
fn the_binary_exits_two_on_an_unsupported_hello() {
    assert_eq!(refused_hello().0.code(), Some(2));
}

#[test]
fn the_binary_answers_an_unsupported_hello_with_a_version_error() {
    let reply: serde_json::Value = serde_json::from_str(&refused_hello().1.concat()).unwrap();
    assert_eq!(reply["code"], "version");
}
