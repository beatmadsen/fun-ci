# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/fake_renderers"
require_relative "../../support/process_deadline"
require "fun_ci/console/launcher"
require "fun_ci/persistence/database"
require "stringio"

# AT-5.1: the console runs its renderer until the user quits, and says so,
# exiting 1, when the renderer stops first; the renderer's stderr goes to the
# project's .fun-ci/console.log, as the terminal is the renderer's.
class TestLauncher < Minitest::Test
  include DatabaseTestSetup
  include ProcessDeadline

  def setup
    setup_test_db
    @stderr = StringIO.new
  end

  def teardown = teardown_test_db

  def launch(script)
    renderer = FakeRenderers.write(@dir, script)
    within_deadline { FunCi::Console::Launcher.run(renderer: renderer, db: @db, project_dir: @dir, stderr: @stderr) }
  end

  def test_should_exit_zero_once_the_user_quits
    assert_equal 0, launch(FakeRenderers::QUITS)
  end

  def test_should_exit_one_when_the_renderer_stops_first
    assert_equal 1, launch(FakeRenderers::DIES)
  end

  def test_should_exit_one_when_the_renderer_fails_on_its_way_out
    assert_equal 1, launch(FakeRenderers::CRASHES_ON_QUIT)
  end

  def test_should_say_the_renderer_stopped_and_where_to_look
    launch(FakeRenderers::DIES)

    assert_includes @stderr.string, "the renderer stopped (pid"
  end

  def test_should_point_at_the_console_log_when_the_renderer_stops
    launch(FakeRenderers::DIES)

    assert_includes @stderr.string, ".fun-ci/console.log"
  end

  def test_should_put_the_renderer_s_stderr_in_the_console_log
    launch(FakeRenderers::GRUMBLES)

    assert_includes File.read(File.join(@dir, ".fun-ci", "console.log")), "the renderer grumbles"
  end
end
