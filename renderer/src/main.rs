use std::env;
use std::io;
use std::process::exit;

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::cli::{EXIT_USAGE, Headless, Options};
use fun_ci_renderer::headless;
use fun_ci_renderer::session::run_session;
use fun_ci_renderer::tty::Tty;

fn main() {
    exit(run(env::args().skip(1)));
}

fn run(args: impl Iterator<Item = String>) -> i32 {
    match Options::parse(args).and_then(|options| Ok((options.library()?, options.headless()?))) {
        Ok((library, Some(run))) => replay(&run, &library),
        Ok((_library, None)) => run_session(io::stdin().lock(), io::stdout().lock(), &mut Tty::default()),
        Err(message) => usage(&message),
    }
}

fn replay(run: &Headless, library: &Library) -> i32 {
    headless::run(run, library).map_or_else(|message| usage(&message), |()| 0)
}

fn usage(message: &str) -> i32 {
    eprintln!("fun-ci-renderer: {message}");
    EXIT_USAGE
}
