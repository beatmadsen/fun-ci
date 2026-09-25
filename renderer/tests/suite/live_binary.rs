//! AT-3.8 prep against the real binary on a pseudo-terminal: a live console
//! that draws what Ruby sends and tells Ruby what the user types and when the
//! terminal changes size. The test waits on output conditions, each with a
//! deadline that fails it rather than hang, never on a fixed time.

use std::ffi::CString;
use std::io::{self, BufRead, BufReader, Write};
use std::os::unix::process::CommandExt;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError};
use std::thread;
use std::time::Duration;

use serde_json::{Value, json};

use crate::support::boards::{board, run};
use crate::support::pty::Pty;

const PATIENCE: Duration = Duration::from_secs(10);
const LEAVE_ALTERNATE_SCREEN: &str = "\u{1b}[?1049l";

/// The renderer drawing on `pty`, which is also its controlling terminal, so
/// resizing the pty signals it as resizing a real terminal would.
fn renderer_controlled_by(pty: &Pty) -> Child {
    let path = CString::new(pty.path.clone()).unwrap();
    let mut command = Command::new(env!("CARGO_BIN_EXE_fun-ci-renderer"));
    command.args(["--tty", &pty.path]).stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::null());
    unsafe { command.pre_exec(move || take_as_controlling_terminal(&path)) };
    command.spawn().unwrap()
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

fn send(stdin: &mut ChildStdin, line: &str) {
    stdin.write_all(format!("{line}\n").as_bytes()).unwrap();
}

/// Each line the renderer writes to stdout, as it comes.
fn replies(stdout: impl io::Read + Send + 'static) -> Receiver<Value> {
    let (sender, receiver) = mpsc::channel();
    thread::spawn(move || {
        for line in BufReader::new(stdout).lines().map_while(Result::ok) {
            let _ = sender.send(serde_json::from_str(&line).unwrap());
        }
    });
    receiver
}

/// The renderer on `pty`, after it has answered `hello` with `ready`.
fn ready_renderer(pty: &Pty) -> (Child, ChildStdin, Receiver<Value>) {
    let mut child = renderer_controlled_by(pty);
    let (mut stdin, replies) = (child.stdin.take().unwrap(), replies(child.stdout.take().unwrap()));
    send(&mut stdin, r#"{"t":"hello","v":1}"#);
    assert_eq!(replies.recv_timeout(PATIENCE).unwrap()["t"], "ready");
    (child, stdin, replies)
}

/// Whether the renderer closes its output, as it does on exiting, within
/// `patience`.
fn closes_within(replies: &Receiver<Value>, patience: Duration) -> bool {
    matches!(replies.recv_timeout(patience), Err(RecvTimeoutError::Disconnected))
}

fn board_on_branch(branch: &str) -> String {
    let mut drawn = run(1, "passed", &[("lint", "passed")]);
    drawn["branch"] = json!(branch);
    board(&[drawn])
}

#[test]
fn a_live_renderer_draws_the_board_sends_keys_and_resizes_and_restores_the_terminal_on_quit() {
    let mut pty = Pty::open();
    let (mut child, mut stdin, replies) = ready_renderer(&pty);
    send(&mut stdin, &board_on_branch("livemark"));
    assert!(pty.shows_within("livemark", PATIENCE), "the board never reached the terminal");

    pty.type_keys(b"j");
    assert_eq!(replies.recv_timeout(PATIENCE).unwrap(), json!({"t":"key","key":"j"}));
    pty.resize(120, 40);
    assert_eq!(replies.recv_timeout(PATIENCE).unwrap(), json!({"t":"resize","cols":120,"rows":40}));

    send(&mut stdin, r#"{"t":"quit"}"#);
    assert!(closes_within(&replies, PATIENCE), "the renderer did not exit on quit");
    assert_eq!(child.wait().unwrap().code(), Some(0));
    assert!(!pty.is_raw(), "the terminal was left in raw mode");
    assert!(pty.close().contains(LEAVE_ALTERNATE_SCREEN));
}
