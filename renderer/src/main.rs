use std::io;
use std::process::exit;

use fun_ci_renderer::session::run_session;
use fun_ci_renderer::tty::Tty;

fn main() {
    let mut tty = Tty::default();
    exit(run_session(io::stdin().lock(), io::stdout().lock(), &mut tty));
}
