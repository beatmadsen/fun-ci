//! A pseudo-terminal for real-process tests of the renderer.

use std::ffi::CStr;
use std::fs::File;
use std::io::Read;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::sync::{Mutex, PoisonError};
use std::thread::{self, JoinHandle};

static ALLOCATING: Mutex<()> = Mutex::new(());

/// A pseudo-terminal whose output a thread reads until the pty closes.
pub struct Pty {
    slave: OwnedFd,
    pub path: String,
    drain: JoinHandle<Vec<u8>>,
}

impl Pty {
    /// A 100x30 pty.
    pub fn open() -> Self {
        Self::sized(100, 30)
    }

    /// Both ends are close-on-exec, so renderers other tests start in parallel
    /// never hold this pty open.
    pub fn sized(cols: u16, rows: u16) -> Self {
        let (master, slave, path) = allocate(cols, rows);
        let mut master = unsafe { File::from_raw_fd(master) };
        let drain = thread::spawn(move || read_until_closed(&mut master));
        Self { slave: unsafe { OwnedFd::from_raw_fd(slave) }, path, drain }
    }

    pub fn is_raw(&self) -> bool {
        let mut modes: libc::termios = unsafe { std::mem::zeroed() };
        assert_eq!(unsafe { libc::tcgetattr(self.slave.as_raw_fd(), &raw mut modes) }, 0);
        modes.c_lflag & libc::ICANON == 0
    }

    /// Closes the pty and returns everything written to it.
    pub fn close(self) -> String {
        drop(self.slave);
        String::from_utf8_lossy(&self.drain.join().unwrap()).into_owned()
    }
}

/// macOS's `openpty` and `ttyname_r` go through shared state, so concurrent
/// tests take turns here.
fn allocate(cols: u16, rows: u16) -> (i32, i32, String) {
    let _turn = ALLOCATING.lock().unwrap_or_else(PoisonError::into_inner);
    let (master, slave) = open_pair(cols, rows);
    close_on_exec(master);
    close_on_exec(slave);
    (master, slave, device_path(slave))
}

fn open_pair(cols: u16, rows: u16) -> (i32, i32) {
    let (mut master, mut slave) = (0, 0);
    let mut size = libc::winsize { ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0 };
    let (name, modes) = (std::ptr::null_mut(), std::ptr::null_mut());
    let opened = unsafe { libc::openpty(&raw mut master, &raw mut slave, name, modes, &raw mut size) };
    assert_eq!(opened, 0, "openpty: {}", std::io::Error::last_os_error());
    (master, slave)
}

fn device_path(fd: i32) -> String {
    let mut name = [0 as libc::c_char; 256];
    assert_eq!(unsafe { libc::ttyname_r(fd, name.as_mut_ptr(), name.len()) }, 0);
    unsafe { CStr::from_ptr(name.as_ptr()) }.to_string_lossy().into_owned()
}

fn close_on_exec(fd: i32) {
    assert_eq!(unsafe { libc::fcntl(fd, libc::F_SETFD, libc::FD_CLOEXEC) }, 0);
}

fn read_until_closed(master: &mut File) -> Vec<u8> {
    let mut bytes = Vec::new();
    let mut chunk = [0; 4096];
    while let Ok(read @ 1..) = master.read(&mut chunk) {
        bytes.extend_from_slice(&chunk[..read]);
    }
    bytes
}
