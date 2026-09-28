# frozen_string_literal: true

require "coverage"

# Ruby's line coverage counts a one-line method's line once, when the method
# is defined, and never for a call: the body shares the def's line, so no
# line event fires. Mutineer picks the tests for a mutant by line coverage,
# so every mutant in an endless method (`def x = ...`) was "no coverage" and
# never run. Method coverage does count those calls; this adds them to the
# line counts. For the mutation lane only (test/mutation_boot.rb).
module EndlessCoverage
  # A Coverage.result with each one-line method's calls added to its line.
  def self.fold(result)
    result.transform_values { |data| data.is_a?(Hash) && data[:methods] ? with_calls(data) : data }
  end

  def self.with_calls(data)
    lines = data[:lines].dup
    data[:methods].each do |(_, _, first, _, last, _), calls|
      lines[first - 1] += calls if first == last
    end
    data.merge(lines: lines)
  end

  # Coverage.result, folded.
  module Folded
    def result(...) = EndlessCoverage.fold(super)
  end

  # Starts coverage afresh with method counts; files loaded from here on are
  # measured, which in the mutation lane is all of lib/.
  def self.install
    Coverage.result(stop: true) if Coverage.running?
    Coverage.start(lines: true, methods: true)
    Coverage.singleton_class.prepend(Folded)
  end
end
