# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/call_scanner"

# AT-0.5: unit and acceptance tests never start a process or send a signal;
# the tests that must live in test/integration/process. SpawnGuard catches the
# spawns this scan can't see, the ones made through lib code.
class TestFastLanesNeverSpawn < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  FAST_LANES = "test/{unit,acceptance}/**/*.rb"

  def test_unit_and_acceptance_sources_never_start_a_process
    assert_empty CallScanner.scan(ROOT, FAST_LANES, CallScanner::SPAWNING)
  end

  def test_the_scan_reads_both_lanes
    assert_equal %w[acceptance unit], Dir.glob(FAST_LANES, base: ROOT).map { |path| path.split("/")[1] }.uniq.sort
  end

  def test_the_runtime_spawn_guard_is_installed
    assert_includes Minitest::Test.ancestors, SpawnGuard::TrackTest
  end
end
