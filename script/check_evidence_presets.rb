# frozen_string_literal: true

# Records each preset's failing run again, in a scratch directory, from its
# recipe with the image's tag in place of its pinned digest, so the tools the
# image provides are their newest release of that tag, and reports what
# changed in what the preset picks out (architecture.md, "Evidence of a failed
# stage"). Tools a recipe installs at a pinned version stay at it. Exits 1 when
# a preset no longer sees its tool's signature or picks out nothing. For the
# scheduled workflow, outside the gate.
#
#   ruby script/check_evidence_presets.rb [NAME...]
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require_relative "record_evidence_fixture"
require_relative "excerpt_comparison"
require "fun_ci/evidence/catalog"
require "fun_ci/evidence/context"
require "fun_ci/evidence/deadline"
require "fun_ci/evidence/presets"
require "fun_ci/evidence/source"

NEVER = FunCi::Evidence::Deadline.new(clock: -> { 0 }, at: 1)

# The excerpts the preset picks out of `output`, each as its lines.
def picked(preset, output)
  entry = FunCi::Evidence::Catalog.entry({ "use" => preset.use, "preset" => preset.name })
  context = FunCi::Evidence::Context.new(stage: "fast", output: output, worktree: nil, deadline: NEVER)
  entry.extractor.extract(context).excerpts.map { |excerpt| excerpt[:lines] }
end

def signed?(preset, output)
  FunCi::Evidence::Source.of("output", output).lines.any? { |line| Regexp.new(preset.signature).match?(line) }
end

def fresh_output(name)
  recipe = YAML.safe_load_file(File.join(fixture_dir(name), "recipe.yml"))
  recipe = recipe.merge("image" => recipe.fetch("image").sub(/@sha256:\h+\z/, ""))
  Dir.mktmpdir do |work|
    write_project(recipe.fetch("files"), work)
    Dir.mktmpdir { |out| run_output(recipe, work, out) }
  end
end

def run_output(recipe, work, out)
  in_container(recipe, work, out)
  File.binread(File.join(out, "output")).force_encoding(Encoding::UTF_8)
end

def recorded(name) = File.binread(File.join(fixture_dir(name), "output.log")).force_encoding(Encoding::UTF_8)

# What is wrong with the preset against a fresh run, or nil after saying whether what it picks out changed.
def check(preset)
  output = fresh_output(preset.name)
  return "#{preset.name}: its signature no longer matches" if preset.signature && !signed?(preset, output)
  return "#{preset.name}: picks out nothing" if picked(preset, output).empty?

  puts "#{preset.name}: #{changed?(preset, output) ? "changed" : "unchanged"}"
end

def changed?(preset, output) = !ExcerptComparison.same?(picked(preset, recorded(preset.name)), picked(preset, output))

if $PROGRAM_NAME == __FILE__
  presets = FunCi::Evidence::Presets.all.select { |preset| ARGV.empty? || ARGV.include?(preset.name) }
  broken = presets.filter_map { |preset| check(preset) }
  broken.each { |line| puts line }
  exit(broken.empty? ? 0 : 1)
end
