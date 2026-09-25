//! A pseudo-terminal for real-process tests of the renderer.

use std::ffi::CStr;
use std::fs::{File, OpenOptions};
use std::os::unix::fs::OpenOptionsExt;
use std::io::{Read, Write};
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::sync::{Arc, Condvar, Mutex, PoisonError};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

static ALLOCATING: Mutex<()> = Mutex::new(());

/// Everything written to the pty so far, and a signal each time more comes.
type Drawn = Arc<(Mutex<Vec<u8>>, Condvar)>;

/// A pseudo-terminal whose output a thread reads until the pty closes.
pub struct Pty {
    slave: OwnedFd,
    pub path: String,
    keyboard: File,
    drain: (JoinHandle<()>, Drawn),
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
        let keyboard = master.try_clone().unwrap();
        let written = Drawn::default();
        let sink = written.clone();
        let reader = thread::spawn(move || read_until_closed(&mut master, &sink));
        Self { slave: unsafe { OwnedFd::from_raw_fd(slave) }, path, keyboard, drain: (reader, written) }
    }

    /// Types `keys` as if at the keyboard.
    pub fn type_keys(&mut self, keys: &[u8]) {
        self.keyboard.write_all(keys).unwrap();
    }

    /// Whether `text` has been written to the pty within `patience`; waits on
    /// each write, never on time alone.
    pub fn shows_within(&self, text: &str, patience: Duration) -> bool {
        let deadline = Instant::now() + patience;
        let (bytes, written) = &*self.drain.1;
        let mut seen = bytes.lock().unwrap();
        while !String::from_utf8_lossy(&seen).contains(text) {
            let Some(left) = deadline.checked_duration_since(Instant::now()) else { return false };
            seen = written.wait_timeout(seen, left).unwrap().0;
        }
        true
    }

    /// Gives the pty a new size, which signals SIGWINCH to its foreground
    /// process group (a process it is the controlling terminal of).
    pub fn resize(&self, cols: u16, rows: u16) {
        let size = libc::winsize { ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0 };
        assert_eq!(unsafe { libc::ioctl(self.slave.as_raw_fd(), libc::TIOCSWINSZ, &raw const size) }, 0);
    }

    /// Reads the modes through a fresh handle: when a process the pty was
    /// the controlling terminal of exits, macOS revokes the handles open on it.
    pub fn is_raw(&self) -> bool {
        let device = OpenOptions::new().read(true).custom_flags(libc::O_NOCTTY).open(&self.path).unwrap();
        let mut modes: libc::termios = unsafe { std::mem::zeroed() };
        assert_eq!(unsafe { libc::tcgetattr(device.as_raw_fd(), &raw mut modes) }, 0);
        modes.c_lflag & libc::ICANON == 0
    }

    /// Closes the pty and returns everything written to it.
    pub fn close(self) -> String {
        drop((self.slave, self.keyboard));
        self.drain.0.join().unwrap();
        String::from_utf8_lossy(&self.drain.1.0.lock().unwrap()).into_owned()
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

fn read_until_closed(master: &mut File, drawn: &Drawn) {
    let mut chunk = [0; 4096];
    while let Ok(read @ 1..) = master.read(&mut chunk) {
        drawn.0.lock().unwrap().extend_from_slice(&chunk[..read]);
        drawn.1.notify_all();
    }
}
