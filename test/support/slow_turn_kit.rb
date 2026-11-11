# frozen_string_literal: true

require "fileutils"
require "fun_ci/pipeline/slow_turns"

# SlowTurns over a test's root (`@root`), with the wait standing in for each
# pass's block until newer suites are done, and tickets held as a live slow
# suite holds them (closed by the test, from `@held`).
module SlowTurnKit
  TICKET = FunCi::Pipeline::TurnTicket
  ROUNDS = FunCi::Pipeline::SlowTurns::ROUNDS

  # By default, a wait that fails the test if there is any newer suite to wait for.
  def turns(wait: ->(paths) { flunk "waited for #{paths}" unless paths.empty? })
    FunCi::Pipeline::SlowTurns.new(@root, wait: wait)
  end

  def hold_ticket(ticket, branch: "main")
    path = turns.ticket_path(branch, ticket)
    FileUtils.mkdir_p(File.dirname(path))
    File.new(path, File::RDWR | File::CREAT, 0o644).tap { |file| file.flock(File::LOCK_EX) }.tap { |file| @held << file }
  end
end
