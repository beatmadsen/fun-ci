# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/cli_project"

# Subcommands that need no git repository. The ones that ask git are in
# test/integration/process/test_cli_hook_subcommands.rb.
class TestCliInitSubcommand < Minitest::Test
  include CliProject

  def test_init_succeeds_for_a_ruby_project
    add_gemfile

    assert_equal 0, run_cli("init")
  end

  def test_init_creates_fun_ci_directory_through_cli
    add_gemfile
    run_cli("init")

    assert fun_ci_dir_exists?
  end

  def test_init_skips_when_fun_ci_already_exists
    add_gemfile
    Dir.mkdir(File.join(@dir, ".fun-ci"))

    assert_equal 0, run_cli("init")
  end
end

class TestCliCheckSubcommand < Minitest::Test
  include CliProject
  include FunCiTestProject

  def test_check_succeeds_for_configured_project
    make_project_with_scripts(@dir)

    assert_equal 0, run_cli("check")
  end

  def test_check_fails_when_scripts_missing
    assert_equal 1, run_cli("check")
  end
end

module DatabaseTables
  def table_names(path)
    db = SQLite3::Database.new(path)
    db.execute("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name").flatten
  ensure
    db&.close
  end
end

class TestCliTriggerSubcommand < Minitest::Test
  include CliProject
  include DatabaseTables

  def test_trigger_sets_up_its_database_before_anything_else
    run_cli("trigger", "abc1234", "main")

    assert_equal %w[pipeline_runs stage_jobs trunk_checks trunk_fetches],
                 table_names(File.join(@dir, "db", "db.sqlite3"))
  end

  def test_trigger_lets_the_commit_through_when_the_project_has_no_fun_ci_folder
    assert_equal 0, run_cli("trigger", "abc1234", "main")
  end

  def test_trigger_says_the_project_has_no_fun_ci_folder
    run_cli("trigger", "abc1234", "main")

    assert_match(%r{No \.fun-ci/ folder found}, @stdout.string)
  end
end

# Agent commands route through the CLI; an option they don't take is refused
# before git is asked anything (AT-9.2).
class TestCliAgentSubcommands < Minitest::Test
  include CliProject

  def test_status_refuses_an_option_it_does_not_take_as_a_usage_error
    assert_equal 64, run_cli("status", "--bogus")
  end
end

# `console` without a renderer it can run says so before starting anything.
class TestCliConsoleWithoutRenderer < Minitest::Test
  def test_should_say_the_renderer_fun_ci_renderer_names_is_not_a_program
    assert_equal [1, "FUN_CI_RENDERER names /no/such/renderer, which is not a program fun-ci can run.\n"],
                 console_with_renderer("/no/such/renderer")
  end

  private

  def console_with_renderer(path)
    stderr = StringIO.new
    previous = ENV.fetch("FUN_CI_RENDERER", nil)
    ENV["FUN_CI_RENDERER"] = path
    [FunCi::Cli.run(["console"], io: FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: stderr)), stderr.string]
  ensure
    ENV["FUN_CI_RENDERER"] = previous
  end
end
