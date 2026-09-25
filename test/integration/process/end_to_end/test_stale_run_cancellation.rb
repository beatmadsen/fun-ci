# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/blocked_run"

# AT-1.6: a newer commit on the branch cancels the run still going for an
# older one: every process of the old run ends, stage scripts included, the
# run is recorded cancelled, and its slot is free.
class TestStaleRunCancellation < Minitest::Test
  include BlockedRun

  def setup
    create_blocked_project
    @old = commit_stages(fast: "#{say_started}\n#{park("fast")}", slow: park("slow"))
    new = commit_stages(fast: "true", slow: "true")
    pid, all_gone = start_blocked_run(@old)
    trigger(@project, new, db_dir: db_dir)
    release_and_wait(pid, all_gone)
  end

  def teardown = remove_blocked_project

  def test_no_stage_script_of_the_old_run_outlives_the_cancel
    refute File.exist?(outlived)
  end

  def test_the_old_run_is_recorded_cancelled
    assert_equal "cancelled", status_of(@old)
  end

  def test_the_old_run_s_slot_is_free
    assert slot_free?
  end
end
