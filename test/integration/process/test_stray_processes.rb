# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/stray_processes"
require_relative "../../support/process_deadline"

# What StrayProcesses stops is each found process's whole group, so that one
# listed before its group's leader, or whose leader names no directory, takes
# the rest of its group with it. Killing it alone let its shell carry on.
class TestStrayProcesses < Minitest::Test
  include ProcessDeadline

  # A group whose leader names no directory and whose member, a shell, names
  # `dir`; each waits for input only teardown ends, so only killing the group
  # ends the leader with a signal.
  MEMBER = %(sh -c "echo started; read _" "$NAMED"; read _)

  def setup
    @dir = Dir.mktmpdir("stray")
    reader, writer = IO.pipe
    @leader = leader(writer)
    writer.close
    within_deadline { reader.gets }
  end

  def teardown
    @hold.close
    FileUtils.rm_rf(@dir)
  end

  def test_should_kill_the_group_of_a_process_it_finds
    StrayProcesses.stop([@dir])

    assert_equal "KILL", Signal.signame(within_deadline { Process.wait2(@leader) }.last.termsig.to_i)
  end

  private

  def leader(out)
    input, @hold = IO.pipe
    Process.spawn({ "NAMED" => File.join(@dir, "member") }, "sh", "-c", MEMBER, in: input, out: out, err: File::NULL,
                                                                                pgroup: true).tap { input.close }
  end
end
