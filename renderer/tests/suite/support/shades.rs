//! Canvas colours as the bytes a terminal is sent, and canvases painted in blocks.

use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::{Shade, float};
use fun_ci_renderer::art::cells::byte;

pub fn rgb(shade: Shade) -> [u8; 3] {
    shade.map(byte)
}

/// Paints the `size` (width, height) rectangle of pixels from `corner` in `shade`.
pub fn fill_rect(canvas: &mut Canvas, corner: (usize, usize), size: (usize, usize), shade: Shade) {
    let (left, top) = (float(corner.0), float(corner.1));
    let (right, bottom) = (left + float(size.0), top + float(size.1));
    canvas.map(|x, y, pixel| if (left..right).contains(&x) && (top..bottom).contains(&y) { shade } else { pixel });
}
