// Joins PNG frames of one size into a lossless animated WebP that loops for
// ever, each frame shown for the same time: a README animation a fraction
// the size of an animated PNG, since WebP keeps only what changed.
//
//   node animate.mjs <out.webp> <delay ms> <frame.png>...
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import ffmpeg from "ffmpeg-static";

const [out, delay, ...frames] = process.argv.slice(2);
const seconds = Number(delay) / 1000;
const list = join(tmpdir(), `frames-${process.pid}.txt`);
writeFileSync(list, frames.map((frame) => `file '${frame}'\nduration ${seconds}\n`).join("") + `file '${frames.at(-1)}'\n`);
execFileSync(ffmpeg, ["-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", list,
  "-c:v", "libwebp_anim", "-lossless", "1", "-loop", "0", "-vsync", "vfr", out]);
