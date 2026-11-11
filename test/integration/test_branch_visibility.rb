# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/branch_visibility"

# Which branches the console keeps out of view (design.md, The console): an
# ignored one until it is shown again, a snoozed one until a run of it starts
# after the snooze (acceptance-tests.md, AT-13.33).
class TestBranchVisibility < Minitest::Test
  include DatabaseTestSetup

  SNOOZED = Time.utc(2026, 10, 2, 12)

  def setup
    setup_test_db
    @visibility = FunCi::Persistence::BranchVisibility.new(@db)
  end

  def teardown = teardown_test_db

  def test_should_keep_an_ignored_branch_out_of_view
    @visibility.hide("/p", "wip", "ignored", at: SNOOZED)

    assert_equal({ %w[/p wip] => "ignored" }, @visibility.hidden)
  end

  def test_should_keep_an_ignored_branch_out_of_view_when_it_runs_again
    @visibility.hide("/p", "wip", "ignored", at: SNOOZED)
    run_of("/p", "wip", at: SNOOZED + 60)

    assert_equal({ %w[/p wip] => "ignored" }, @visibility.hidden)
  end

  def test_should_keep_a_snoozed_branch_out_of_view_while_it_has_not_run_since
    run_of("/p", "wip", at: SNOOZED - 60)
    snooze

    assert_equal({ %w[/p wip] => "snoozed" }, @visibility.hidden)
  end

  def test_should_bring_a_snoozed_branch_back_when_a_run_of_it_starts
    snooze
    run_of("/p", "wip", at: SNOOZED + 1)

    assert_empty @visibility.hidden
  end

  # Runs are kept to the second, a snooze to the millisecond.
  def test_should_keep_a_branch_snoozed_for_a_run_started_in_the_second_it_was_snoozed
    @visibility.hide("/p", "wip", "snoozed", at: SNOOZED + 0.5)
    run_of("/p", "wip", at: SNOOZED)

    assert_equal({ %w[/p wip] => "snoozed" }, @visibility.hidden)
  end

  def test_should_not_bring_a_snoozed_branch_back_for_another_branch_s_run
    snooze
    run_of("/p", "main", at: SNOOZED + 60)

    assert_equal({ %w[/p wip] => "snoozed" }, @visibility.hidden)
  end

  def test_should_not_bring_a_snoozed_branch_back_for_another_project_s_run_of_its_name
    snooze
    run_of("/other", "wip", at: SNOOZED + 60)

    assert_equal({ %w[/p wip] => "snoozed" }, @visibility.hidden)
  end

  def test_should_show_a_hidden_branch_again_when_told_to
    @visibility.hide("/p", "wip", "ignored", at: SNOOZED)
    @visibility.show("/p", "wip")

    assert_empty @visibility.hidden
  end

  def test_should_keep_the_latest_of_two_ways_a_branch_was_hidden
    snooze
    @visibility.hide("/p", "wip", "ignored", at: SNOOZED + 1)

    assert_equal({ %w[/p wip] => "ignored" }, @visibility.hidden)
  end

  private

  def snooze = @visibility.hide("/p", "wip", "snoozed", at: SNOOZED)

  def run_of(project, branch, at:)
    @db.execute("INSERT INTO pipeline_runs (commit_hash, branch, project_path, status, created_at, updated_at) " \
                "VALUES (?, ?, ?, 'completed', ?, ?)", ["a" * 40, branch, project, at.utc.iso8601, at.utc.iso8601])
  end
end
