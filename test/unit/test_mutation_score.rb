# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../renderer/tools/mutation_score"

# AT-3.9: `rake mutation:rust` passes only when at least 90% of cargo-mutants'
# viable mutants are caught, read from mutants.out/outcomes.json.
class TestMutationScore < Minitest::Test
  SCORE = FunCi::Mutation::Score

  def score(caught:, missed: 0, timeout: 0, unviable: 0)
    SCORE.new("caught" => caught, "missed" => missed, "timeout" => timeout, "unviable" => unviable)
  end

  def test_the_share_caught_leaves_out_unviable_mutants
    assert_in_delta 90.0, score(caught: 9, missed: 1, unviable: 5).percent
  end

  def test_a_timed_out_mutant_counts_against_the_share
    assert_in_delta 80.0, score(caught: 8, missed: 1, timeout: 1).percent
  end

  def test_ninety_percent_passes_a_ninety_percent_threshold
    assert score(caught: 9, missed: 1).passes?(90)
  end

  def test_just_under_ninety_percent_fails_it
    refute score(caught: 899, missed: 101).passes?(90)
  end

  def test_no_viable_mutants_fails
    refute score(caught: 0).passes?(90)
  end

  def test_the_summary_names_the_counts_and_the_share
    assert_equal "caught 9 of 10 viable mutants (90.0%): missed 1, timeout 0, unviable 5",
                 score(caught: 9, missed: 1, unviable: 5).summary
  end

  def test_cargo_mutants_finding_missed_mutants_is_left_to_the_score
    assert FunCi::Mutation.completed?(2)
  end

  def test_a_failing_baseline_is_not_a_completed_run
    refute FunCi::Mutation.completed?(4)
  end
end
