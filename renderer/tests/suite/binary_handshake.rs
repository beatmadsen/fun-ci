//! The real binary refuses a version it does not speak, before it touches
//! the terminal (so it needs none).

use std::io::Write;
use std::process::{Command, Output, Stdio};

fn refused_hello() -> Output {
    let mut child = Command::new(env!("CARGO_BIN_EXE_fun-ci-renderer"))
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();
    child.stdin.take().unwrap().write_all(b"{\"t\":\"hello\",\"v\":9}\n").unwrap();
    child.wait_with_output().unwrap()
}

#[test]
fn the_binary_exits_two_on_an_unsupported_hello() {
    assert_eq!(refused_hello().status.code(), Some(2));
}

#[test]
fn the_binary_answers_an_unsupported_hello_with_a_version_error() {
    let reply: serde_json::Value = serde_json::from_slice(&refused_hello().stdout).unwrap();
    assert_eq!(reply["code"], "version");
}
