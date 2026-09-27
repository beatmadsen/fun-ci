# frozen_string_literal: true

# Times what choosing presets costs a failed stage (architecture.md, "Evidence
# of a failed stage"): the one scan of a full output window (1 MB + 7 MB) for
# every preset's signature, with every preset a candidate, and each preset
# reading the window. The window is the recorded runs in
# test/fixtures/evidence/, repeated. Run it when a preset is added.
#
#   ruby script/bench_detection.rb
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "benchmark"
require "fun_ci/evidence/detection"
require "fun_ci/evidence/catalog"
require "fun_ci/evidence/context"
require "fun_ci/evidence/deadline"
require "fun_ci/evidence/source"
require "fun_ci/pipeline/output_window"

FIXTURES = File.expand_path("../test/fixtures/evidence", __dir__)
NEVER = FunCi::Evidence::Deadline.new(clock: -> { 0 }, at: 1)

# The recorded runs, repeated past the window's size, as the window keeps them.
def window
  recorded = Dir.glob("*/output.log", base: FIXTURES).map { |path| File.binread(File.join(FIXTURES, path)) }.join
  output = FunCi::Pipeline::OutputWindow.in_memory
  output << (recorded * ((9_000_000 / recorded.bytesize) + 1))
  output.text.force_encoding(Encoding::UTF_8)
end

def seconds(&) = Benchmark.realtime(&).round(3)

text = window
lines = FunCi::Evidence::Source.of("output", text).lines
presets = FunCi::Evidence::Presets.all
candidates = presets.map { |preset| FunCi::Evidence::Detection::Found.new(preset: preset, because: nil) }
puts "window: #{text.bytesize} bytes, #{lines.size} lines, #{presets.size} presets"
puts "joined signature scan: #{seconds { FunCi::Evidence::Detection.chosen(text, candidates, NEVER) }}s"
context = FunCi::Evidence::Context.new(stage: "fast", output: text, worktree: nil, deadline: NEVER)
presets.each do |preset|
  entry = FunCi::Evidence::Catalog.entry({ "use" => preset.use, "preset" => preset.name })
  puts format("  %-12<name>s %<time>.3fs", name: preset.name, time: seconds { entry.extractor.extract(context) })
end
