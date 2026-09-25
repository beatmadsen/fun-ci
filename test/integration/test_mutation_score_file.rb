# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../renderer/tools/mutation_score"
require "json"
require "tmpdir"

# AT-3.9: the lane reads cargo-mutants' mutants.out/outcomes.json.
class TestMutationScoreFile < Minitest::Test
  SCORE = FunCi::Mutation::Score

  def test_the_score_is_read_from_outcomes_json
    Dir.mktmpdir do |dir|
      path = File.join(dir, "outcomes.json")
      File.write(path, JSON.generate("caught" => 3, "missed" => 1, "timeout" => 0, "unviable" => 0, "outcomes" => []))
      assert_in_delta 75.0, SCORE.load(path).percent
    end
  end
end
