// Draws frames of a headless fun-ci-renderer run in xterm.js, a real
// terminal emulator, in a 26-pixel font: the README's pictures, sharper than
// the renderer's own 8-pixel bitmap-font PNGs. Its canvas
// renderer draws block, quadrant and box characters itself, filling the
// cell, where a font's glyphs would leave gaps between rows.
//
//   node capture.mjs <frames.cast> <out dir> <frame>...
//
// Each frame is a 1-based frame number of the run; frame N is the screen
// after the cast's first N outputs, saved as <out dir>/NNNN.png.
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join } from "node:path";
import { chromium } from "playwright";

const FONT_SIZE = 26;
const NIGHT = "#0c0a13";

const [cast, out, ...wanted] = process.argv.slice(2);
const require = createRequire(import.meta.url);
const asset = (path) => readFileSync(require.resolve(path), "utf8");
const lines = readFileSync(cast, "utf8").trim().split("\n");
const { width, height } = JSON.parse(lines[0]);
const outputs = lines.slice(1).map((line) => JSON.parse(line)[2]);

const page = `<!doctype html><html><head><meta charset="utf-8">
<style>${asset("@xterm/xterm/css/xterm.css")} html,body{margin:0;background:${NIGHT}}</style>
<script>${asset("@xterm/xterm/lib/xterm.js")}</script>
<script>${asset("@xterm/addon-canvas/lib/addon-canvas.js")}</script></head><body><div id="t"></div><script>
  const term = new Terminal({ cols: ${width}, rows: ${height}, fontSize: ${FONT_SIZE}, lineHeight: 1.0,
    fontFamily: 'Menlo, monospace', customGlyphs: true, drawBoldTextInBrightColors: false, cursorInactiveStyle: 'none',
    theme: { background: '${NIGHT}', cursor: '${NIGHT}' } });
  term.open(document.getElementById('t'));
  term.loadAddon(new CanvasAddon.CanvasAddon());
  term.write('\\x1b[?25l');
  window.write = (data) => new Promise((done) => term.write(data, () => requestAnimationFrame(() => requestAnimationFrame(done))));
</script></body></html>`;

const browser = await chromium.launch();
const tab = await (await browser.newContext({ viewport: { width: 3200, height: 2400 } })).newPage();
await tab.setContent(page);
await tab.evaluate(() => document.fonts.ready);
let shown = 0;
for (const frame of wanted.map(Number).sort((a, b) => a - b)) {
  await tab.evaluate((data) => window.write(data), outputs.slice(shown, frame).join(""));
  shown = frame;
  await tab.locator(".xterm-screen").screenshot({ path: join(out, `${String(frame).padStart(4, "0")}.png`) });
}
await browser.close();
