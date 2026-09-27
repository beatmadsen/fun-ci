# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"

# `fun-ci runs` lists the project's recent runs (acceptance-tests.md, AT-9.4).
class TestAgentRuns < Minitest::Test
  PASSED = { "lint" => "completed", "build" => "completed", "fast" => "completed", "slow" => "completed" }.freeze

  def setup
    @client = AgentClient.open
    @client.git.commit("aaa1111aaaa", "First")
    @client.git.commit("bbb2222bbbb", "Second")
    @client.git.commit("ccc3333cccc", "Third")
  end

  def teardown = @client.close

  def test_should_list_the_project_s_runs_newest_first
    @client.record_run("aaa1111aaaa", stages: PASSED)
    @client.record_run("bbb2222bbbb", branch: "feature", stages: { "lint" => "failed" })

    @client.runs

    assert_equal %w[bbb2222 aaa1111], shas
  end

  def test_should_give_each_run_its_branch_age_stage_outcomes_and_subject
    @client.record_run("aaa1111aaaa", stages: PASSED.merge("slow" => "failed"))

    @client.runs

    assert_equal "aaa1111  main  just now  lint ok    build ok    fast ok    slow FAIL  First",
                 @client.stdout.lines.first.chomp
  end

  def test_should_leave_out_other_projects_runs
    @client.record_run("aaa1111aaaa", project: "/another/project")

    @client.runs

    assert_empty @client.stdout
  end

  def test_should_list_at_most_the_number_asked_for
    %w[aaa1111aaaa bbb2222bbbb ccc3333cccc].each { |sha| @client.record_run(sha) }

    @client.runs("-n", "2")

    assert_equal %w[ccc3333 bbb2222], shas
  end

  def test_should_list_only_the_branch_asked_for
    @client.record_run("aaa1111aaaa")
    @client.record_run("bbb2222bbbb", branch: "feature")

    @client.runs("--branch", "main")

    assert_equal %w[aaa1111], shas
  end

  def test_should_list_each_run_as_a_status_document_with_json
    @client.record_run("aaa1111aaaa", stages: PASSED)

    @client.runs("--json")

    assert_equal([%w[aaa1111aaaa passed]], JSON.parse(@client.stdout).map do |run|
      [run["commit"]["sha"], run["verdict"]]
    end)
  end

  def test_should_refuse_a_count_that_is_not_a_number
    assert_equal 64, @client.runs("-n", "many")
  end

  private

  def shas = @client.stdout.lines.map { |line| line[0, 7] }
end
