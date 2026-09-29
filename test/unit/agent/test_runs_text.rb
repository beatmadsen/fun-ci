# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/runs_text"
require "fun_ci/trunk/shown"

class TestRunsText < Minitest::Test
  REPORT = FunCi::Agent::RunReport
  STAGE = REPORT::Stage
  CLEAN = FunCi::Trunk::Merge.clean(ahead: 1, behind: 1)

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

  def test_should_mark_a_run_that_conflicts_with_the_trunk_before_its_subject
    report = report("aaa1111aaaa", "main", "First", %w[passed passed passed passed]).with(trunk: conflicting)

    assert_match(%r{slow ok    conflicts origin/main  First\z},
                 FunCi::Agent::RunsText.lines([[report, "2m ago"]]).first)
  end

  def test_should_mark_nothing_for_a_run_that_merges_cleanly
    report = report("aaa1111aaaa", "main", "First", %w[passed passed passed passed]).with(trunk: shown(CLEAN))

    assert_match(/slow ok    First\z/, FunCi::Agent::RunsText.lines([[report, "2m ago"]]).first)
  end

  private

  def conflicting = shown(FunCi::Trunk::Merge.conflicts(["a.rb"], ahead: 1, behind: 1))

  def shown(merge)
    tip = FunCi::Trunk::Tip.new(remote: "origin", branch: "main", sha: "fff", seen_at: Time.utc(2026, 9, 29))
    FunCi::Trunk::Shown.of(FunCi::Trunk::Check.new(commit: "aaa", tip: tip, merge: merge), now: Time.utc(2026, 9, 29))
  end

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
