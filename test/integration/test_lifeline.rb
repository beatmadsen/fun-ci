# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/lifeline"
require "tmpdir"

# Closing a lifeline that is still held kills the holders' group, which may
# already be exiting under a kill of the code under test: macOS then refuses
# the signal with EPERM, or finds no process left, ESRCH. The test holds the
# lifeline itself, and the kill it injects answers as the kernel did.
class TestLifeline < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry @dir
  end

  def test_should_close_when_the_holders_group_is_exiting
    assert_nil close_while_held(refusing_with(Errno::EPERM))
  end

  def test_should_close_when_the_holders_group_is_gone
    assert_nil close_while_held(refusing_with(Errno::ESRCH))
  end

  private

  def refusing_with(error) = ->(*) { raise error }

  def close_while_held(kill)
    lifeline = Lifeline.new(@dir, kill: kill)
    File.write(File.join(@dir, "lifeline.group"), "4242\n")
    File.open(File.join(@dir, "lifeline"), "w") do |holder|
      holder.syswrite("held\n")
      lifeline.close
    end
  end
end
