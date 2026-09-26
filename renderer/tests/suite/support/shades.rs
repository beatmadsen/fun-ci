//! Canvas colours as the bytes a terminal is sent.

use fun_ci_renderer::art::Shade;
use fun_ci_renderer::art::cells::byte;

pub fn rgb(shade: Shade) -> [u8; 3] {
    shade.map(byte)
}
