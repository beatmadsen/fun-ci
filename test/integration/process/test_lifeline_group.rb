# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require_relative "../../support/lifeline"
require_relative "../../support/fifo"
require "tmpdir"
require "shellwords"
require "io/nonblock"

# A holder need not lead its group, as a fetch's ssh does not: closing the
# lifeline still held kills the group the holder is in. The group's leader
# waits on a pipe the test holds, made blocking as Ruby's pipes are not, and
# not on the holder: a group's members are signalled one at a time, and under
# load a leader waiting on the holder saw it die and exited 0 before the KILL
# reached it.
class TestLifelineGroup < Minitest::Test
  include ProcessDeadline

  def setup
    @dir = Dir.mktmpdir
    @hold_in, @hold = IO.pipe
    @hold_in.nonblock = false
  end

  def teardown
    @hold.close
    FileUtils.remove_entry(@dir)
  end

  def test_should_kill_the_group_of_a_holder_that_leads_none_when_closed_while_held
    leader = Lifeline.open(@dir) { |lifeline| held_by_a_member(lifeline) }

    assert(within_deadline { Process.wait2(leader).last.signaled? })
  end

  private

  # The leader starts a member that holds the lifeline, and waits on the
  # test's pipe; answers the leader's pid.
  def held_by_a_member(lifeline)
    ready = File.join(@dir, "ready").tap { |path| File.mkfifo(path) }
    member = Shellwords.escape("#{lifeline.hold}; echo > #{ready}; exec sleep 300")
    leader = Process.spawn("sh -c #{member} & read _ <&5", pgroup: true, 5 => @hold_in)
    @hold_in.close
    Fifo.read(ready)
    leader
  end
end
