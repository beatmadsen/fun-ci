# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/runs_text"

class TestRunsText < Minitest::Test
  REPORT = FunCi::Agent::RunReport
  STAGE = REPORT::Stage

  def test_should_give_a_run_its_sha_branch_age_stages_and_subject
    assert_equal ["aaa1111  main  2m ago  lint ok    build ok    fast FAIL  slow -     First"],
                 lines(["aaa1111aaaa", "main", "First", %w[passed passed failed waiting], "2m ago"])
  end

  def test_should_name_every_state_in_a_word_of_four_letters_at_most
    words = lines(["aaa1111aaaa", "main", "First", %w[over_budget running cancelled waiting], "2m ago"]).first

    assert_includes words, "lint OVER  build ...   fast x     slow -"
  end

  def test_should_line_the_columns_up_across_runs
    assert_equal(["aaa1111  main     just now  lint ok", "bbb2222  feature  12m ago   lint ok"],
                 lines(["aaa1111aaaa", "main", "First", %w[passed passed passed passed], "just now"],
                       ["bbb2222bbbb", "feature", "Second", %w[passed passed passed passed], "12m ago"])
                   .map { |line| line[/\A.*?lint ok/] })
  end

  private

  def lines(*runs)
    FunCi::Agent::RunsText.lines(runs.map { |*run, age| [report(*run), age] })
  end

  def report(sha, branch, subject, states)
    stages = %w[lint build fast slow].zip(states).map do |name, state|
      STAGE.new(name: name, state: state, seconds: nil)
    end
    REPORT.new(sha: sha, subject: subject, branch: branch, need: "all", stages: stages, verdict: :undecided,
               superseded_by: nil)
  end
end
