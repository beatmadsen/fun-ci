//! The real terminal: `/dev/tty` (or `--tty <path>`), so the stdin/stdout
//! pipes never carry terminal bytes. Opened on `enter`, so a refused
//! handshake never touches it.

use std::fs::{File, OpenOptions};
use std::io::{self, Write};
use std::os::fd::AsRawFd;
use std::path::PathBuf;
use std::sync::{Mutex, PoisonError};

use crate::terminal::Terminal;

const ENTER: &[u8] = b"\x1b[?1049h\x1b[?25l";
const LEAVE: &[u8] = b"\x1b[?25h\x1b[?1049l";

static ENTERED: Mutex<Option<Entered>> = Mutex::new(None);

struct Entered {
    file: File,
    modes: libc::termios,
}

/// A terminal device by path.
pub struct Tty {
    path: PathBuf,
}

impl Tty {
    #[must_use]
    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }
}

impl Default for Tty {
    fn default() -> Self {
        Self::new(PathBuf::from("/dev/tty"))
    }
}

impl Terminal for Tty {
    fn size(&self) -> (u16, u16) {
        with_entered(|entered| window_size(&entered.file)).flatten().unwrap_or((80, 24))
    }

    fn enter(&mut self) -> io::Result<()> {
        let mut file = OpenOptions::new().read(true).write(true).open(&self.path)?;
        let modes = get_modes(&file)?;
        set_modes(&file, &raw(modes))?;
        file.write_all(ENTER)?;
        *lock() = Some(Entered { file, modes });
        Ok(())
    }

    fn restore(&mut self) -> io::Result<()> {
        restore_controlling_terminal()
    }
}

/// Leaves the alternate screen and raw mode if this process entered them,
/// from any thread (a signal handler's, say). Does nothing the second time.
///
/// # Errors
/// When the terminal refuses the mode change.
pub fn restore_controlling_terminal() -> io::Result<()> {
    restore_once(&ENTERED, |mut entered| {
        entered.file.write_all(LEAVE)?;
        set_modes(&entered.file, &entered.modes)
    })
}

/// Takes what `slot` saved and restores it with `restore`, holding the slot
/// until `restore` returns, so a second caller (the signal thread racing the
/// main one) cannot see the slot empty and exit mid-restore.
///
/// # Errors
/// Whatever `restore` returns.
pub fn restore_once<T>(slot: &Mutex<Option<T>>, restore: impl FnOnce(T) -> io::Result<()>) -> io::Result<()> {
    let mut held = slot.lock().unwrap_or_else(PoisonError::into_inner);
    held.take().map_or(Ok(()), restore)
}

fn lock() -> std::sync::MutexGuard<'static, Option<Entered>> {
    ENTERED.lock().unwrap_or_else(PoisonError::into_inner)
}

fn with_entered<T>(action: impl FnOnce(&mut Entered) -> T) -> Option<T> {
    lock().as_mut().map(action)
}

fn raw(mut modes: libc::termios) -> libc::termios {
    unsafe { libc::cfmakeraw(&raw mut modes) };
    modes
}

fn get_modes(file: &File) -> io::Result<libc::termios> {
    let mut modes = unsafe { std::mem::zeroed::<libc::termios>() };
    let status = unsafe { libc::tcgetattr(file.as_raw_fd(), &raw mut modes) };
    if status == 0 { Ok(modes) } else { Err(io::Error::last_os_error()) }
}

fn set_modes(file: &File, modes: &libc::termios) -> io::Result<()> {
    let status = unsafe { libc::tcsetattr(file.as_raw_fd(), libc::TCSAFLUSH, modes) };
    if status == 0 { Ok(()) } else { Err(io::Error::last_os_error()) }
}

fn window_size(file: &File) -> Option<(u16, u16)> {
    let mut size = libc::winsize { ws_row: 0, ws_col: 0, ws_xpixel: 0, ws_ypixel: 0 };
    unsafe { libc::ioctl(file.as_raw_fd(), libc::TIOCGWINSZ, &raw mut size) };
    (size.ws_col > 0).then_some((size.ws_col, size.ws_row))
}
