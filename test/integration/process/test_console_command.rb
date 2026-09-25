# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/fake_renderers"
require_relative "../../support/process_deadline"
require "json"
require "open3"
require "tmpdir"

# AT-5.1: `fun-ci console` starts the renderer it finds and talks to it; with
# no renderer, only `console` fails, saying how to get one. How the console
# ends is the Launcher's (test_launcher.rb).
class TestConsoleCommand < Minitest::Test
  include ProcessDeadline

  FUN_CI = File.expand_path("../../../exe/fun-ci", __dir__)
  NO_RENDERER = { "FUN_CI_RENDERER" => nil, "PATH" => "/usr/bin:/bin" }.freeze

  def setup = @dir = Dir.mktmpdir
  def teardown = FileUtils.rm_rf(@dir)

  def run_fun_ci(env, *args)
    env = { "TMPDIR" => @dir }.merge(env)
    within_deadline { Open3.capture3(env, RbConfig.ruby, FUN_CI, *args, chdir: @dir, stdin_data: "", pgroup: true) }
  end

  def heard = File.readlines("#{File.join(@dir, "renderer")}.heard").map { |line| JSON.parse(line)["t"] }

  def test_should_talk_to_the_renderer_fun_ci_renderer_names
    run_fun_ci({ "FUN_CI_RENDERER" => FakeRenderers.write(@dir, FakeRenderers::QUITS) }, "console")

    assert_equal %w[hello board quit], heard
  end

  def test_should_say_how_to_get_a_renderer_when_there_is_none
    _, stderr, status = run_fun_ci(NO_RENDERER, "console")

    assert_equal [1, true], [status.exitstatus, stderr.include?("cargo install fun-ci-renderer")]
  end

  def test_should_run_other_commands_without_a_renderer
    _, _, status = run_fun_ci(NO_RENDERER, "--help")

    assert_predicate status, :success?
  end
end
