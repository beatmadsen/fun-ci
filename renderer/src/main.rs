use std::env;
use std::io;
use std::process::exit;

use fun_ci_renderer::cli::{EXIT_USAGE, Options};
use fun_ci_renderer::session::run_session;
use fun_ci_renderer::tty::Tty;

fn main() {
    exit(run(env::args().skip(1)));
}

fn run(args: impl Iterator<Item = String>) -> i32 {
    match Options::parse(args).and_then(|options| options.library()) {
        Ok(_library) => run_session(io::stdin().lock(), io::stdout().lock(), &mut Tty::default()),
        Err(message) => {
            eprintln!("fun-ci-renderer: {message}");
            EXIT_USAGE
        }
    }
}
