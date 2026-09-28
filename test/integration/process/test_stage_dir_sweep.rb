# frozen_string_literal: true

require_relative "../../test_helper"
require "tmpdir"
require "fun_ci/pipeline/stage_dir"

# A stage's directory holds its output unmasked until the stage is recorded,
# so one a crash left behind is removed when the next stage starts (architecture.md,
# "Evidence of a failed stage").
class TestStageDirSweep < Minitest::Test
  def setup = @root = Dir.mktmpdir
  def teardown = FileUtils.remove_entry(@root)

  def test_should_remove_the_directory_of_a_process_that_has_died
    dead = File.join(@root, "#{exited_pid}-abc").tap { |dir| Dir.mkdir(dir) }
    FunCi::Pipeline::StageDir.create(@root).remove

    refute Dir.exist?(dead)
  end

  def test_should_keep_the_directory_of_a_process_still_running
    live = File.join(@root, "#{Process.pid}-abc").tap { |dir| Dir.mkdir(dir) }
    FunCi::Pipeline::StageDir.create(@root).remove

    assert Dir.exist?(live)
  end

  # Process 1 always runs, as root: a user may not signal it, so asking
  # whether it lives is refused rather than answered.
  def test_should_keep_the_directory_of_a_process_it_may_not_signal
    other = File.join(@root, "1-abc").tap { |dir| Dir.mkdir(dir) }
    FunCi::Pipeline::StageDir.create(@root).remove

    assert Dir.exist?(other)
  end

  private

  def exited_pid
    pid = Process.spawn("true")
    Process.wait(pid)
    pid
  end
end
