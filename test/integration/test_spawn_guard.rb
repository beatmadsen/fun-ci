# frozen_string_literal: true

require_relative "../test_helper"
require "open3"
require "tmpdir"

# AT-0.5: a unit or acceptance test fails if it starts a process, even one
# started for it by code outside the test file. The probe suite names its own
# directory as the fast lane through FUN_CI_FAST_LANES.
class TestSpawnGuard < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
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

  private

  def probe_output(body, lanes: nil)
    Dir.mktmpdir("spawn-guard") do |dir|
      File.write(File.join(dir, "helper.rb"), HELPER)
      File.write(File.join(dir, "test_probe.rb"), probe(body))
      env = { "FUN_CI_FAST_LANES" => lanes || File.realpath(dir) }
      Open3.capture2e(env, "ruby", "-I#{ROOT}/test", "-I#{ROOT}/lib", "test_probe.rb", chdir: dir).first
    end
  end

  def probe(body)
    <<~RUBY
      require "test_helper"
      require_relative "helper"
      class TestProbe < Minitest::Test
        def test_probe
          #{body}
        end
      end
    RUBY
  end
end
