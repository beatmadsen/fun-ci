# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/fake_renderers"
require_relative "../../support/process_deadline"
require "fun_ci/console/launcher"
require "fun_ci/persistence/database"
require "stringio"

# AT-5.1: the console runs its renderer until the user quits, and says so,
# exiting 1, when the renderer stops first or the console itself fails; the
# renderer's stderr, when the console started and stopped, and what made it
# fail go to the project's .fun-ci/console.log, as the terminal is the
# renderer's and anything printed on it is gone once the renderer leaves.
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

  def console_log = File.read(File.join(@dir, ".fun-ci", "console.log"))

  # Every poll of the runs then fails, as it would on a database that went bad.
  def break_the_database = %w[stage_jobs pipeline_runs].each { |table| @db.execute("DROP TABLE #{table}") }

  def test_should_log_that_the_console_started_with_the_renderer_s_pid
    launch(FakeRenderers::QUITS)

    assert_match(/console started; the renderer is pid \d+/, console_log)
  end

  def test_should_log_that_the_console_stopped_when_the_user_quit
    launch(FakeRenderers::QUITS)

    assert_match(/console stopped: the user quit; the renderer exited \(pid \d+ exit 0\)/, console_log)
  end

  def test_should_log_that_the_console_stopped_when_the_renderer_went_away
    launch(FakeRenderers::DIES)

    assert_includes console_log, "console stopped: the renderer went away"
  end

  def test_should_exit_one_when_the_console_fails
    break_the_database

    assert_equal 1, launch(FakeRenderers::QUITS)
  end

  def test_should_log_the_error_that_made_the_console_fail
    break_the_database
    launch(FakeRenderers::QUITS)

    assert_match(/console stopped: it failed: SQLite3::SQLException: no such table/, console_log)
  end

  def test_should_log_where_the_error_that_made_the_console_fail_was_raised
    break_the_database
    launch(FakeRenderers::QUITS)

    assert_match(%r{^\s+.*lib/fun_ci/console/board_data\.rb:\d+}, console_log)
  end

  def test_should_say_on_stderr_what_made_the_console_fail
    break_the_database
    launch(FakeRenderers::QUITS)

    assert_includes @stderr.string, "fun-ci console failed (SQLite3::SQLException: no such table"
  end

  def test_should_stop_the_renderer_when_the_console_fails
    break_the_database
    launch(FakeRenderers::QUITS)

    assert_raises(Errno::ESRCH) { Process.kill(0, console_log[/the renderer is pid (\d+)/, 1].to_i) }
  end

  def test_should_put_the_renderer_s_stderr_in_the_console_log
    launch(FakeRenderers::GRUMBLES)

    assert_includes File.read(File.join(@dir, ".fun-ci", "console.log")), "the renderer grumbles"
  end
end
