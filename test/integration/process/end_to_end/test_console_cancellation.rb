# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/blocked_run"

# AT-1.12: cancelling a run from the console stops it, whether its fast
# suite is still running in the foreground or only its slow suite is left in
# the background: every process ends, the run is recorded cancelled, and its
# slot is free. The console's BoardData#cancel_run is what `c` then `y` calls.
module ConsoleCancellation
  include BlockedRun

  def setup
    create_blocked_project
    @sha = commit_stages(**stages)
    run = start_blocked_run(@sha)
    with_db { |db| FunCi::Console::BoardData.new(db).cancel_run(run_id_of(@sha)) }
    release_and_wait(run)
  end

  def teardown = remove_blocked_project

  def test_no_stage_script_outlives_the_cancel
    refute File.exist?(outlived)
  end

  def test_the_run_is_recorded_cancelled
    assert_equal "cancelled", status_of(@sha)
  end

  def test_the_run_s_slot_is_free
    assert slot_free?
  end
end

class TestConsoleCancellationInTheForeground < Minitest::Test
  include ConsoleCancellation

  def stages = { fast: "#{say_started}\n#{park("fast")}", slow: park("slow") }
end

class TestConsoleCancellationOfTheSlowSuite < Minitest::Test
  include ConsoleCancellation

  def stages = { fast: "true", slow: "#{say_started}\n#{park("slow")}" }
end
