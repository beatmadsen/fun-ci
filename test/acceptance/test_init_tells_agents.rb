# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/cli_project"

# `fun-ci init` tells agents what to do after a commit (acceptance-tests.md,
# AT-9.15), in the instructions file agents read.
class TestInitTellsAgents < Minitest::Test
  include CliProject

  def test_should_create_agents_md_with_the_instruction_when_the_project_has_none
    init

    assert_includes read("AGENTS.md").tr("\n", " "), "run the `fun-ci wait` command it prints, in the background"
  end

  # A wait that follows the branch lets a newer commit cancel the older run
  # rather than run its slow suite beside it (AT-9.12).
  def test_should_tell_agents_a_newer_commit_moves_the_wait_on_to_its_run
    init

    assert_includes read("AGENTS.md").tr("\n", " "),
                    "A newer commit on the branch cancels the run and the wait moves on to"
  end

  def test_should_tell_agents_to_integrate_the_trunk_before_calling_work_done
    init

    assert_includes read("AGENTS.md").tr("\n", " "), "run `fun-ci wait --need all --trunk`; 6 means"
  end

  def test_should_add_the_instruction_to_an_existing_agents_md_and_keep_what_is_there
    File.write(path("AGENTS.md"), "# Our rules\n\nBe kind.\n")
    init

    assert_match(/\A# Our rules\n\nBe kind\.\n\n## fun-ci\n/, read("AGENTS.md"))
  end

  def test_should_add_the_instruction_to_claude_md_when_it_is_the_only_one
    File.write(path("CLAUDE.md"), "# Rules\n")
    init

    assert_equal [true, false], [read("CLAUDE.md").include?("## fun-ci"), File.exist?(path("AGENTS.md"))]
  end

  def test_should_add_nothing_the_second_time
    init
    first = read("AGENTS.md")
    init

    assert_equal first, read("AGENTS.md")
  end

  def test_should_say_where_it_told_agents
    init

    assert_includes @stdout.string, "Told agents what to do after a commit, in AGENTS.md."
  end

  private

  def init
    add_gemfile
    run_cli("init")
  end

  def path(name) = File.join(@dir, name)
  def read(name) = File.read(path(name))
end
