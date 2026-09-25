# frozen_string_literal: true

# Stands in for the keyboard and terminal of `fun-ci console`. Waiting for a key
# suspends the run loop's fiber and hands the loop's refresh interval to the test,
# which resumes it with a key, or with nil when the interval passes with no key.
class ScriptedTerminal
  attr_reader :modes

  def initialize(width_provider:)
    @real = FunCi::Tui::TerminalInput.new(input: nil, width_provider: width_provider)
    @modes = []
  end

  def check_width = @real.check_width
  def setup_raw_mode = @modes << :raw
  def restore_terminal = @modes << :cooked

  # A real terminal traps SIGWINCH here; resizes are driven by the test instead.
  def setup_signal_trap; end

  def read_key_with_timeout(timeout) = Fiber.yield(timeout)
end
