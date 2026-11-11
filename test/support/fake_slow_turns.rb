# frozen_string_literal: true

# The turns a branch's slow suites take, given at once, or never (as while an
# older slow suite of the branch still runs), keeping which branch asked, and
# with which ticket.
class FakeSlowTurns
  attr_reader :asked, :tickets

  def initialize(given: true)
    @given = given
    @asked = []
    @tickets = []
  end

  def take(branch, ticket)
    @asked << branch
    @tickets << ticket
    yield if @given
  end
end
