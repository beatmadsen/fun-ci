# frozen_string_literal: true

require "coverage"

# Ruby's line coverage counts a statement on the line it starts, so a line a
# statement continues onto has no count, and a one-line method's calls are
# never counted: its body shares the def's line, counted once when the
# method is defined. Mutineer picks the tests for a mutant by the count of
# its line, so every mutant on such a line was "no coverage" and never run.
# Method coverage knows where each method is and how often it ran; this
# counts each line a statement spans. A clause (when, in, rescue, else,
# elsif, ensure) starts a branch, not a continuation, so it and what
# continues it keep no count rather than a count they didn't earn. For the
# mutation lane only (test/mutation_boot.rb).
module StatementCoverage
  CLAUSE = /\A\s*(?:when|in|rescue|else|elsif|ensure)\b/

  # A Coverage.result with each one-line method's calls on its line, and
  # each continuation line inside a method counted as its statement is.
  # `read` answers a file's lines.
  def self.fold(result, read: File.method(:readlines))
    result.to_h { |path, data| [path, data.is_a?(Hash) && data[:methods] ? counted(data, read.call(path)) : data] }
  end

  def self.counted(data, source)
    lines = data[:lines].dup
    data[:methods].each do |(_, _, first, _, last, _), calls|
      first == last ? lines[first - 1] += calls : continue_statements(lines, source, first...last)
    end
    data.merge(lines: lines)
  end

  # Lines first + 1 to last, at indexes first to last - 1.
  def self.continue_statements(lines, source, indexes)
    indexes.each { |index| lines[index] ||= lines[index - 1] unless source[index]&.match?(CLAUSE) }
  end

  # Coverage.result, folded.
  module Folded
    def result(...) = StatementCoverage.fold(super)
  end

  # Starts coverage afresh with method counts; files loaded from here on are
  # measured, which in the mutation lane is all of lib/.
  def self.install
    Coverage.result(stop: true, clear: true) if Coverage.running?
    Coverage.start(lines: true, methods: true)
    Coverage.singleton_class.prepend(Folded)
  end
end
