# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require_relative "../../support/lifeline"
require_relative "../../support/fifo"
require "tmpdir"
require "shellwords"

# A holder need not lead its group, as a fetch's ssh does not: closing the
# lifeline still held kills the group the holder is in.
class TestLifelineGroup < Minitest::Test
  include ProcessDeadline

  def setup = @dir = Dir.mktmpdir
  def teardown = FileUtils.remove_entry(@dir)

  def test_should_kill_the_group_of_a_holder_that_leads_none_when_closed_while_held
    leader = Lifeline.open(@dir) { |lifeline| held_by_a_member(lifeline) }

    assert(within_deadline { Process.wait2(leader).last.signaled? })
  end

  private

  # The leader waits on a member that holds the lifeline; answers the leader's pid.
  def held_by_a_member(lifeline)
    ready = File.join(@dir, "ready").tap { |path| File.mkfifo(path) }
    member = Shellwords.escape("#{lifeline.hold}; echo > #{ready}; exec sleep 300")
    leader = Process.spawn("sh -c #{member} & wait", pgroup: true)
    Fifo.read(ready)
    leader
  end
end
