# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_kit"
require "fun_ci/agent/trunk_why"

# A conflict with the trunk as evidence `why REV trunk` prints (docs/trunk-conflicts.md, why REV trunk).
class TestTrunkWhy < Minitest::Test
  include TrunkKit

  CONFLICT = "keep\n<<<<<<< ours\nmine\n=======\ntheirs\n>>>>>>> trunk\n"
  EXPLAINED = FunCi::Trunk::Explained.new(messages: ["CONFLICT (content): Merge conflict in a.rb"],
                                          files: { "a.rb" => CONFLICT })
  TIP = FunCi::Trunk::Tip.new(remote: "origin", branch: "main", sha: TRUNK_SHA, seen_at: Time.utc(2026, 9, 29))

  def test_should_keep_git_s_messages_as_the_first_excerpt
    assert_equal ["CONFLICT (content): Merge conflict in a.rb"], document.excerpts.first[:lines]
  end

  def test_should_keep_each_conflicted_region_under_its_file_and_lines
    assert_equal ["a.rb", "lines 1-6"], document.excerpts.last.values_at(:title, :location)
  end

  def test_should_number_each_line_of_a_region
    assert_equal "   2  <<<<<<< ours", document.excerpts.last[:lines][1]
  end

  def test_should_label_the_commit_s_side_of_a_conflict_by_its_short_sha
    assert_equal "   2  <<<<<<< abc1234", labelled.excerpts.last[:lines][1]
  end

  def test_should_label_the_trunk_s_side_of_a_conflict_by_its_name
    assert_equal "   6  >>>>>>> origin/main", labelled.excerpts.last[:lines][5]
  end

  def test_should_say_when_the_commits_merged_are_gone
    assert_equal "origin/main 9e1d004 or the commit is no longer in this repository",
                 FunCi::Agent::TrunkWhy.document(nil, TIP).problems.first[:message]
  end

  private

  def labelled
    commit = "abc1234#{"0" * 33}"
    text = "keep\n<<<<<<< #{commit}\nmine\n=======\ntheirs\n>>>>>>> #{TRUNK_SHA}\n"
    FunCi::Agent::TrunkWhy.document(FunCi::Trunk::Explained.new(messages: [], files: { "a.rb" => text }), TIP)
  end

  def document = FunCi::Agent::TrunkWhy.document(EXPLAINED, TIP)
end
