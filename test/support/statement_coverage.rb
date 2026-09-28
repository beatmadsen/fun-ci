# frozen_string_literal: true

require "coverage"

# Ruby's line coverage counts a statement on the line it starts, so a line a
# statement continues onto has no count, and a one-line method's calls are
# never counted: its body shares the def's line, counted once when the
# method is defined. Mutineer picks the tests for a mutant by the count of
# its line, so every mutant on such a line was "no coverage" and never run.
# Method coverage knows where each method is and how often it ran; this
# counts each line a statement spans. For the mutation lane only
# (test/mutation_boot.rb).
module StatementCoverage
  # A Coverage.result with each one-line method's calls on its line, and
  # each continuation line inside a method counted as its statement is.
  def self.fold(result)
    result.transform_values { |data| data.is_a?(Hash) && data[:methods] ? counted(data) : data }
  end

  def self.counted(data)
    lines = data[:lines].dup
    data[:methods].each do |(_, _, first, _, last, _), calls|
      first == last ? lines[first - 1] += calls : continue_statements(lines, first, last)
    end
    data.merge(lines: lines)
  end

  # Lines first + 1 to last, at indexes first to last - 1.
  def self.continue_statements(lines, first, last)
    (first...last).each { |index| lines[index] ||= lines[index - 1] }
  end

  # Coverage.result, folded.
  module Folded
    def result(...) = StatementCoverage.fold(super)
  end

  # Starts coverage afresh with method counts; files loaded from here on are
  # measured, which in the mutation lane is all of lib/.
  def self.install
    Coverage.result(stop: true) if Coverage.running?
    Coverage.start(lines: true, methods: true)
    Coverage.singleton_class.prepend(Folded)
  end
end
