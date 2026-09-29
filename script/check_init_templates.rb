# frozen_string_literal: true

# The half of AT-10.21 outside the gate. For each preset whose tool one of its
# stack's stage scripts runs, `fun-ci init` sets up the preset's recorded
# failing project, and that script, run in the recording's pinned image after
# the recipe's setup (and the build script before a test stage, as a pipeline
# runs it), must fail printing what the preset picks out. Then, for each stack,
# the stages that run at once must write nothing in common, and its suites
# must run tests side by side (suites_apart.rb). Needs Docker and the network;
# the weekly evidence workflow runs it.
#
#   ruby script/check_init_templates.rb [PRESET...]
require_relative "initialised_project"
require_relative "suites_apart"
require_relative "../test/support/preset_stacks"

# What is wrong with the preset's stack's script, or nil after saying it is right.
def check_template(preset, stage)
  output, status = initialised_run(stage_recipe(preset.name, stage))
  return "#{preset.name}: #{stage} passed\n#{output}" if status.zero?
  return "#{preset.name}: #{stage} printed no #{preset.name} signature\n#{output}" unless signed?(preset, output)
  return "#{preset.name}: picks out nothing of #{stage}\n#{output}" if picked(preset, output).empty?

  puts "#{preset.name}: #{stage} fails as #{preset.name} reads it"
end

# The first preset of each stack whose fast script runs its tool, whose
# recorded project stands in for the stack.
def suite_stacks
  PresetStacks::STACKS.select { |_, place| place.stage == "fast.sh" }.uniq { |_, place| place.stack }.map(&:first)
end

def apart_verdict(name)
  output, = initialised_run(unbuilt_recipe(name, SuitesApart::SCRIPT))
  preset = FunCi::Evidence::Presets.fetch(name)
  [SuitesApart.verdict(name, output, fast_ran: ->(fast) { !picked(preset, fast).empty? }), output]
end

# What is wrong with the stack's stages run side by side, or nil after saying they keep apart.
def check_apart(name)
  verdict, output = apart_verdict(name)
  return "#{name}: #{verdict.problems.join("; ")}\n#{output}" unless verdict.problems.empty?

  puts ["#{name}: stages side by side write nothing in common, and the suites ran tests", *verdict.notes].join("; "),
       "  #{verdict.measured.join(", ")}"
end

if $PROGRAM_NAME == __FILE__
  chosen = ->(name) { ARGV.empty? || ARGV.include?(name) }
  placed = PresetStacks::STACKS.select { |name, place| place.stage && chosen.call(name) }
  broken = placed.filter_map { |name, place| check_template(FunCi::Evidence::Presets.fetch(name), place.stage) }
  broken += suite_stacks.select(&chosen).filter_map { |name| check_apart(name) }
  broken.each { |report| puts report }
  exit(broken.empty? ? 0 : 1)
end
