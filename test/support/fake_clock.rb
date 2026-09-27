# frozen_string_literal: true

# Time for agent commands that wait, without waiting: each pause moves the
# clock on and runs the next scripted step, which is how a test makes a run
# progress while `wait` polls. Pausing past the script plus `spare` pauses
# raises, so a wait that never ends fails its test instead of hanging it.
class FakeClock
  class OverWaited < StandardError; end

  attr_reader :now, :pauses

  def initialize(now: Time.now, spare: 20)
    @now = now
    @steps = []
    @pauses = 0
    @spare = spare
  end

  def then_do(&step) = @steps << step

  def pause(seconds)
    @pauses += 1
    raise OverWaited, "paused #{@pauses} times" if @steps.empty? && (@spare -= 1).negative?

    @now += seconds
    @steps.shift&.call
  end
end
