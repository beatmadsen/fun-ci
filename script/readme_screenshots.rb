# frozen_string_literal: true

# Draws the README's pictures of the console into docs/screenshots/: each is
# a scenario of pinned scenes, played by the renderer's headless mode
# (docs/renderer-protocol.md, Headless mode), whose terminal output
# script/screenshots/terminal replays in xterm.js, a real terminal emulator,
# in a 26-pixel Menlo (so on macOS); an animation becomes a lossless WebP. Run it again after a change to what
# the console draws and commit the pictures that changed.
#
#   npm run --prefix script/screenshots/terminal setup   # once: xterm.js, Chromium, ffmpeg
#   ruby script/readme_screenshots.rb
require "fileutils"
require "tmpdir"
require_relative "screenshots/shots"

ROOT = File.expand_path("..", __dir__)
RENDERER = File.join(ROOT, "renderer/target/release/fun-ci-renderer")
OUT = File.join(ROOT, "docs/screenshots")
CAPTURE = File.join(ROOT, "script/screenshots/terminal/capture.mjs")
ANIMATE = File.join(ROOT, "script/screenshots/terminal/animate.mjs")

def build_renderer
  system("cargo", "build", "--release", "--quiet", "--manifest-path", File.join(ROOT, "renderer/Cargo.toml"),
         exception: true)
end

def render(shot, dir)
  scenario = File.join(dir, "scenario.jsonl")
  File.write(scenario, shot.scenario.to_s)
  cols, rows = shot.scenario.size.map(&:to_s)
  system(RENDERER, "--headless", "--cols", cols, "--rows", rows, "--scenario", scenario, "--out", dir,
         exception: true)
end

# The shot's frames, drawn in the terminal emulator into `dir`/terminal.
def capture(shot, dir)
  out = FileUtils.mkdir_p(File.join(dir, "terminal")).first
  system("node", CAPTURE, File.join(dir, "frames.cast"), out, *shot.frames.map(&:to_s), exception: true)
end

# A still as a PNG; an animation as a lossless animated WebP.
def save(shot, dir)
  frames = shot.frames.map { |frame| File.join(dir, "terminal", format("%04d.png", frame)) }
  frames.one? ? FileUtils.cp(frames.first, target(shot)) : animate(shot, frames)
end

# Each frame shown as long as the ticks between them, 100 ms a tick.
def animate(shot, frames)
  delay_ms = 100 * (shot.frames[1] - shot.frames[0])
  system("node", ANIMATE, target(shot), delay_ms.to_s, *frames, exception: true)
end

def target(shot) = File.join(OUT, "#{shot.name}.#{shot.frames.one? ? "png" : "webp"}")

build_renderer
FileUtils.mkdir_p(OUT)
Screenshots::Shots.all.each do |shot|
  Dir.mktmpdir do |dir|
    render(shot, dir)
    capture(shot, dir)
    save(shot, dir)
  end
  puts target(shot).delete_prefix("#{ROOT}/")
end
