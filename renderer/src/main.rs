use std::env;
use std::io::{self, BufReader};
use std::path::PathBuf;
use std::process::exit;
use std::sync::mpsc;
use std::thread;
use std::time::SystemTime;

use signal_hook::consts::{SIGHUP, SIGINT, SIGTERM};
use signal_hook::iterator::Signals;

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::animator::seed_at;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::cli::{EXIT_USAGE, Headless, Options};
use fun_ci_renderer::console::Console;
use fun_ci_renderer::headless;
use fun_ci_renderer::live_io::{ChannelInputs, LiveTty, WallClock, read_lines};
use fun_ci_renderer::session::{Session, on_terminate, run_live};
use fun_ci_renderer::tty::restore_controlling_terminal;

fn main() {
    exit(run(env::args().skip(1)));
}

fn run(args: impl Iterator<Item = String>) -> i32 {
    match Options::parse(args).and_then(|options| Ok((options.headless()?, options))) {
        Ok((Some(run), _)) => replay(&run, &Library::builtin()),
        Ok((None, options)) => live(options.tty(), options.depth(env::var("COLORTERM").ok().as_deref())),
        Err(message) => usage(&message),
    }
}

fn live(tty: PathBuf, depth: Depth) -> i32 {
    match Signals::new([SIGTERM, SIGHUP, SIGINT]) {
        Ok(signals) => drop(thread::spawn(move || listen(signals))),
        Err(error) => eprintln!("fun-ci-renderer: signals will not restore the terminal: {error}"),
    }
    let (sender, receiver) = mpsc::channel();
    read_lines(BufReader::new(io::stdin()), sender.clone());
    let session = Session { inputs: ChannelInputs::new(receiver), output: io::stdout().lock(), clock: WallClock::start(), console: console(depth) };
    run_live(session, &mut LiveTty::new(tty, sender))
}

fn console(depth: Depth) -> Console {
    let mut console = Console::new(&Library::builtin(), seed_at(SystemTime::now()), (80, 24));
    console.set_depth(depth);
    console
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
