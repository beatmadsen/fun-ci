# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/spawn_scanner"

# AT-0.5: unit and acceptance tests never start a process; the ones that must
# live in test/integration. SpawnGuard catches the spawns this scan can't see,
# the ones made through lib code.
class TestFastLanesNeverSpawn < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_unit_and_acceptance_sources_never_start_a_process
    assert_empty(fast_lane_files.flat_map { |path| SpawnScanner.new(File.read(path), relative(path)).offences })
  end

  def test_the_scan_reads_both_lanes
    assert_equal %w[acceptance unit], fast_lane_files.map { |path| relative(path).split("/")[1] }.uniq.sort
  end

  def test_the_runtime_spawn_guard_is_installed
    assert_includes Minitest::Test.ancestors, SpawnGuard::TrackTest
  end

  private

  def fast_lane_files = Dir.glob(File.join(ROOT, "test/{unit,acceptance}/**/*.rb"))
  def relative(path) = path.delete_prefix("#{ROOT}/")
end
