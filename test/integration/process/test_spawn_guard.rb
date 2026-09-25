# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/probe_suite"
require "tmpdir"

# AT-0.5: a test outside test/integration/process fails if it starts a
# process, even one started for it by code outside the test file. The probe
# suite names its own directory through FUN_CI_NO_SPAWN_DIRS and a process/
# directory inside it through FUN_CI_SPAWN_DIRS.
class TestSpawnGuard < Minitest::Test
  HELPER = "module Helper\n  def self.run = Process.wait(Process.spawn(\"true\"))\nend\n"

  def test_should_fail_a_fast_lane_test_that_spawns
    assert_match(/TestProbe#test_probe started a process \(system\)/, probe_output(%(system("true"))))
  end

  def test_should_fail_a_fast_lane_test_whose_collaborator_spawns
    assert_match(/TestProbe#test_probe started a process \(Process.spawn\)/, probe_output("Helper.run"))
  end

  def test_should_fail_a_fast_lane_test_that_forks
    assert_match(/TestProbe#test_probe started a process \(fork\)/, probe_output("fork { exit! }"))
  end

  def test_should_let_a_test_outside_the_fast_lanes_spawn
    assert_match(/1 runs, .* 0 failures, 0 errors/, probe_output(%(system("true")), lanes: "/nowhere"))
  end

  def test_should_let_a_test_in_a_process_directory_spawn
    assert_match(/1 runs, .* 0 failures, 0 errors/, probe_output(%(system("true")), subdir: "process"))
  end

  private

  def probe_output(body, lanes: nil, subdir: ".")
    Dir.mktmpdir("spawn-guard") do |dir|
      probe_dir = File.join(dir, subdir).tap { |path| FileUtils.mkdir_p(path) }
      File.write(File.join(probe_dir, "helper.rb"), HELPER)
      env = lanes(lanes || File.realpath(dir))
      ProbeSuite.run(body, dir: probe_dir, preamble: 'require_relative "helper"', env: env).first
    end
  end

  def lanes(root) = { "FUN_CI_NO_SPAWN_DIRS" => root, "FUN_CI_SPAWN_DIRS" => File.join(root, "process") }
end
