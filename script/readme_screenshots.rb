# frozen_string_literal: true

# Draws the README's pictures of the console into docs/screenshots/ with the
# renderer's headless mode (docs/renderer-protocol.md, Headless mode): each is
# a scenario of pinned scenes, so run it again after a change to what the
# console draws and commit the pictures that changed.
#
#   ruby script/readme_screenshots.rb
require "fileutils"
require "tmpdir"
require_relative "screenshots/apng"
require_relative "screenshots/shots"

ROOT = File.expand_path("..", __dir__)
RENDERER = File.join(ROOT, "renderer/target/release/fun-ci-renderer")
OUT = File.join(ROOT, "docs/screenshots")

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

def save(shot, dir)
  frames = shot.frames.map { |frame| File.join(dir, "frames", format("%04d.png", frame)) }
  target = File.join(OUT, "#{shot.name}.png")
  return FileUtils.cp(frames.first, target) if frames.one?

  Screenshots::Apng.write(target, frames, delay_ms: 100 * (shot.frames[1] - shot.frames[0]))
end

build_renderer
FileUtils.mkdir_p(OUT)
Screenshots::Shots.all.each do |shot|
  Dir.mktmpdir do |dir|
    render(shot, dir)
    save(shot, dir)
  end
  puts "docs/screenshots/#{shot.name}.png"
end
