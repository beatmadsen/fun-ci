# frozen_string_literal: true

require_relative "scripted_terminal"

# Runs AdminTui#run, the loop `fun-ci console` runs, inside a fiber. Each call
# lets the loop draw one frame and stop at its next wait for a key.
class RunLoop
  attr_reader :tui, :refresh_interval

  def initialize(tui, terminal)
    @tui = tui
    @terminal = terminal
    @fiber = Fiber.new do
      tui.run
      nil
    end
    @refresh_interval = nil
  end

  def start = feed(nil)
  def exited? = !@fiber.alive?
  def terminal_modes = @terminal.modes

  # nil stands for the refresh interval passing without a key press.
  def feed(key)
    @refresh_interval = @fiber.resume(key)
  end
end
