# frozen_string_literal: true

# The turns a branch's slow suites take, given at once, or never (as while an
# older slow suite of the branch still runs), keeping which branch asked.
class FakeSlowTurns
  attr_reader :asked

  def initialize(given: true)
    @given = given
    @asked = []
  end

  def take(branch)
    @asked << branch
    yield if @given
  end
end
