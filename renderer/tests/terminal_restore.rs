//! AT-3.7 against the real binary, drawing on a pseudo-terminal named with
//! `--tty`: after end of input, `quit` or SIGTERM the terminal is out of raw
//! mode and off the alternate screen. The test waits on `ready`, on process
//! exit and on the pty closing, never on time.

use std::ffi::CStr;
use std::fs::File;
use std::io::{BufRead, BufReader, Read, Write};
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::process::{Child, ChildStdin, Command, ExitStatus, Stdio};
use std::thread::{self, JoinHandle};

const LEAVE_ALTERNATE_SCREEN: &str = "\u{1b}[?1049l";

struct Outcome {
    raw_during: bool,
    raw_after: bool,
    drawn: String,
    status: ExitStatus,
}

struct Pty {
    slave: OwnedFd,
    drain: JoinHandle<Vec<u8>>,
}

impl Pty {
    /// A pseudo-terminal whose output a thread reads until the pty closes.
    fn open() -> Self {
        let (mut master, mut slave) = (0, 0);
        let mut size = libc::winsize { ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0 };
        let (name, modes) = (std::ptr::null_mut(), std::ptr::null_mut());
        assert_eq!(unsafe { libc::openpty(&raw mut master, &raw mut slave, name, modes, &raw mut size) }, 0);
        let mut master = unsafe { File::from_raw_fd(master) };
        let drain = thread::spawn(move || read_until_closed(&mut master));
        Self { slave: unsafe { OwnedFd::from_raw_fd(slave) }, drain }
    }

    fn path(&self) -> String {
        let name = unsafe { CStr::from_ptr(libc::ttyname(self.slave.as_raw_fd())) };
        name.to_string_lossy().into_owned()
    }

    fn is_raw(&self) -> bool {
        let mut modes: libc::termios = unsafe { std::mem::zeroed() };
        assert_eq!(unsafe { libc::tcgetattr(self.slave.as_raw_fd(), &raw mut modes) }, 0);
        modes.c_lflag & libc::ICANON == 0
    }

    fn close(self) -> String {
        drop(self.slave);
        String::from_utf8_lossy(&self.drain.join().unwrap()).into_owned()
    }
}

fn read_until_closed(master: &mut File) -> Vec<u8> {
    let mut bytes = Vec::new();
    let mut chunk = [0; 4096];
    while let Ok(read @ 1..) = master.read(&mut chunk) {
        bytes.extend_from_slice(&chunk[..read]);
    }
    bytes
}

fn renderer(pty: &Pty) -> Child {
    let mut command = Command::new(env!("CARGO_BIN_EXE_fun-ci-renderer"));
    command.args(["--tty", &pty.path()]).stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::null());
    command.spawn().unwrap()
}

/// The renderer, drawing on `pty`, after it has answered `ready`.
fn ready_renderer(pty: &Pty) -> (Child, ChildStdin) {
    let mut child = renderer(pty);
    let mut stdin = child.stdin.take().unwrap();
    stdin.write_all(b"{\"t\":\"hello\",\"v\":1}\n").unwrap();
    BufReader::new(child.stdout.as_mut().unwrap()).read_line(&mut String::new()).unwrap();
    (child, stdin)
}

fn ended_by(end: impl FnOnce(&mut Child, ChildStdin)) -> Outcome {
    let pty = Pty::open();
    let (mut child, stdin) = ready_renderer(&pty);
    let raw_during = pty.is_raw();
    end(&mut child, stdin);
    let status = child.wait().unwrap();
    let raw_after = pty.is_raw();
    Outcome { raw_during, raw_after, drawn: pty.close(), status }
}

fn end_of_input(_: &mut Child, stdin: ChildStdin) {
    drop(stdin);
}

fn quit(_: &mut Child, mut stdin: ChildStdin) {
    stdin.write_all(b"{\"t\":\"quit\"}\n").unwrap();
}

fn sigterm(child: &mut Child, _stdin: ChildStdin) {
    unsafe { libc::kill(i32::try_from(child.id()).unwrap(), libc::SIGTERM) };
}

#[test]
fn the_renderer_puts_its_terminal_in_raw_mode() {
    assert!(ended_by(end_of_input).raw_during);
}

#[test]
fn end_of_input_leaves_raw_mode() {
    assert!(!ended_by(end_of_input).raw_after);
}

#[test]
fn end_of_input_leaves_the_alternate_screen() {
    assert!(ended_by(end_of_input).drawn.contains(LEAVE_ALTERNATE_SCREEN));
}

#[test]
fn quit_leaves_raw_mode() {
    assert!(!ended_by(quit).raw_after);
}

#[test]
fn sigterm_leaves_raw_mode() {
    assert!(!ended_by(sigterm).raw_after);
}

#[test]
fn sigterm_leaves_the_alternate_screen() {
    assert!(ended_by(sigterm).drawn.contains(LEAVE_ALTERNATE_SCREEN));
}

#[test]
fn sigterm_exits_with_the_signal_status() {
    assert_eq!(ended_by(sigterm).status.code(), Some(143));
}

#[test]
fn ready_reports_the_terminal_size() {
    let pty = Pty::open();
    let mut child = renderer(&pty);
    child.stdin.take().unwrap().write_all(b"{\"t\":\"hello\",\"v\":1}\n").unwrap();
    let ready: serde_json::Value = serde_json::from_slice(&child.wait_with_output().unwrap().stdout).unwrap();
    assert_eq!(ready["cols"], 80);
}
