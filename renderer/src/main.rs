use std::env;
use std::io;
use std::path::PathBuf;
use std::process::exit;
use std::thread;

use signal_hook::consts::{SIGHUP, SIGINT, SIGTERM};
use signal_hook::iterator::Signals;

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::cli::{EXIT_USAGE, Headless, Options};
use fun_ci_renderer::headless;
use fun_ci_renderer::session::{on_terminate, run_session};
use fun_ci_renderer::tty::{Tty, restore_controlling_terminal};

fn main() {
    exit(run(env::args().skip(1)));
}

fn run(args: impl Iterator<Item = String>) -> i32 {
    match Options::parse(args).and_then(|options| Ok((options.library()?, options.headless()?, options.tty()))) {
        Ok((library, Some(run), _)) => replay(&run, &library),
        Ok((_library, None, tty)) => live(tty),
        Err(message) => usage(&message),
    }
}

fn live(tty: PathBuf) -> i32 {
    match Signals::new([SIGTERM, SIGHUP, SIGINT]) {
        Ok(signals) => drop(thread::spawn(move || listen(signals))),
        Err(error) => eprintln!("fun-ci-renderer: signals will not restore the terminal: {error}"),
    }
    run_session(io::stdin().lock(), io::stdout().lock(), &mut Tty::new(tty))
}

fn listen(mut signals: Signals) {
    if let Some(signal) = signals.forever().next() {
        on_terminate(signal, restore, |status| exit(status));
    }
}

fn restore() {
    if let Err(error) = restore_controlling_terminal() {
        eprintln!("fun-ci-renderer: could not restore the terminal: {error}");
    }
}

fn replay(run: &Headless, library: &Library) -> i32 {
    headless::run(run, library).map_or_else(|message| usage(&message), |()| 0)
}

fn usage(message: &str) -> i32 {
    eprintln!("fun-ci-renderer: {message}");
    EXIT_USAGE
}
