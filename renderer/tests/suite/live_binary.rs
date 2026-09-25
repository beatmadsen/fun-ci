//! AT-3.8 prep against the real binary on a pseudo-terminal: a live console
//! that draws what Ruby sends and tells Ruby what the user types and when the
//! terminal changes size. The test waits on output conditions, each with a
//! deadline that fails it rather than hang, never on a fixed time.

use std::ffi::CString;
use std::io;
use std::os::unix::process::CommandExt;
use std::process::Stdio;

use serde_json::{Value, json};

use crate::support::boards::{board, run};
use crate::support::pty::Pty;
use crate::support::renderer::{PATIENCE, Renderer, binary};

const LEAVE_ALTERNATE_SCREEN: &str = "\u{1b}[?1049l";

/// The renderer drawing on `pty`, which is also its controlling terminal, so
/// resizing the pty signals it as resizing a real terminal would.
fn renderer_controlled_by(pty: &Pty) -> Renderer {
    let path = CString::new(pty.path.clone()).unwrap();
    let mut command = binary();
    command.args(["--tty", &pty.path]).stderr(Stdio::null());
    unsafe { command.pre_exec(move || take_as_controlling_terminal(&path)) };
    Renderer::start(&mut command)
}

/// Runs in the child between fork and exec: only async-signal-safe calls.
fn take_as_controlling_terminal(path: &CString) -> io::Result<()> {
    let fd = unsafe { libc::setsid(); libc::open(path.as_ptr(), libc::O_RDWR) };
    let taken = set_controlling_terminal(fd);
    unsafe { libc::close(fd) };
    if fd < 0 || taken != 0 { Err(io::Error::last_os_error()) } else { Ok(()) }
}

// `TIOCSCTTY` is a `c_uint` on macOS and the request type elsewhere.
#[cfg(target_os = "macos")]
fn set_controlling_terminal(fd: i32) -> i32 {
    unsafe { libc::ioctl(fd, libc::TIOCSCTTY.into(), 0) }
}

#[cfg(not(target_os = "macos"))]
fn set_controlling_terminal(fd: i32) -> i32 {
    unsafe { libc::ioctl(fd, libc::TIOCSCTTY, 0) }
}

fn reply(renderer: &Renderer) -> Value {
    serde_json::from_str(&renderer.line()).unwrap()
}

/// The renderer on `pty`, after it has answered `hello` with `ready`.
fn ready_renderer(pty: &Pty) -> Renderer {
    let mut renderer = renderer_controlled_by(pty);
    renderer.send(r#"{"t":"hello","v":1}"#);
    assert_eq!(reply(&renderer)["t"], "ready");
    renderer
}

fn board_on_branch(branch: &str) -> String {
    let mut drawn = run(1, "passed", &[("lint", "passed")]);
    drawn["branch"] = json!(branch);
    board(&[drawn])
}

#[test]
fn a_live_renderer_draws_the_board_sends_keys_and_resizes_and_restores_the_terminal_on_quit() {
    let mut pty = Pty::open();
    let mut renderer = ready_renderer(&pty);
    renderer.send(&board_on_branch("livemark"));
    assert!(pty.shows_within("livemark", PATIENCE), "the board never reached the terminal");

    pty.type_keys(b"j");
    assert_eq!(reply(&renderer), json!({"t":"key","key":"j"}));
    pty.resize(120, 40);
    assert_eq!(reply(&renderer), json!({"t":"resize","cols":120,"rows":40}));

    renderer.send(r#"{"t":"quit"}"#);
    assert!(renderer.closes_output(), "the renderer did not exit on quit");
    assert_eq!(renderer.wait().code(), Some(0));
    assert!(!pty.is_raw(), "the terminal was left in raw mode");
    assert!(pty.close().contains(LEAVE_ALTERNATE_SCREEN));
}
