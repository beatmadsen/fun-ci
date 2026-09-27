# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/end_to_end"
require "json"

# AT-9.2 and AT-9.9 through the real CLI: an agent asks `fun-ci status` and
# `fun-ci wait` in a project whose commit a trigger ran, and gets its verdict.
class TestAgentStatusAfterTrigger < Minitest::Test
  include EndToEnd

  def setup
    @project = GitProject.create
    @project.write_stage_scripts { |_stage| "true" }
    @sha = @project.commit("Add stage scripts")
    @db_dir = Dir.mktmpdir("agent-status")
    trigger(@project, @sha, db_dir: @db_dir)
  end

  def teardown = [@project.dir, @db_dir].each { |dir| FileUtils.rm_rf(dir) }

  def test_should_report_the_run_the_trigger_recorded
    assert_equal 0, status("--need", "all")
  end

  def test_should_name_the_commit_by_its_subject
    status

    assert_includes @stdout.string, %(fun-ci: #{@sha[0, 7]} "Add stage scripts" on main)
  end

  def test_should_answer_a_wait_on_a_decided_run_at_once
    assert_equal 0, agent("wait", "--need", "all", "--within", "1")
  end

  def test_should_print_the_run_s_events_as_json_lines
    agent("events")

    finished = { "schema" => 1, "event" => "run_finished", "commit" => @sha, "branch" => "main", "state" => "passed" }

    assert_equal finished, JSON.parse(@stdout.string.lines.last)
  end

  private

  def status(*) = agent("status", *)

  def agent(command, *args)
    @stdout = StringIO.new
    io = FunCi::Pipeline::Io.new(stdout: @stdout, stderr: @stdout)
    Dir.chdir(@project.dir) { FunCi::Cli.run([command, *args], io: io, db_dir: @db_dir) }
  end
end
