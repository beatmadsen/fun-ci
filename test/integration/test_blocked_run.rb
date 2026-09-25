# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/blocked_run"

# BlockedRun's release, against a real FIFO: a stage script killed by the
# cancel can still hold the FIFO open when the test opens it.
class TestBlockedRun < Minitest::Test
  include BlockedRun

  def setup
    @tmp = Dir.mktmpdir("blocked-run")
    File.mkfifo(release)
    @reader = File.open(release, File::RDONLY | File::NONBLOCK)
  end

  def teardown
    @reader.close unless @reader.closed?
    FileUtils.rm_rf(@tmp)
  end

  def test_should_release_a_script_still_waiting
    release_what_survived

    assert_equal "go\n", @reader.read
  end

  def test_should_release_nothing_when_the_last_reader_dies_after_the_open
    assert_nil release_what_survived(after_open: -> { @reader.close })
  end
end
