# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_kit"
require "fun_ci/agent/next_step"

# What an agent is told to do about a conflict with the trunk (design.md, The trunk).
class TestNextStep < Minitest::Test
  include TrunkKit

  NOW = Time.utc(2026, 9, 29, 10)
  WHEN = "Conflicts with origin/main in 2 files. When the task is done, integrate: "

  def test_should_offer_a_merge_first_on_a_branch_other_than_the_trunk
    assert_equal "#{WHEN}git pull origin main (or git pull --rebase origin main if the branch isn't shared)",
                 line(trunk_tip(seen_at: NOW), branch: "feat/cart")
  end

  def test_should_rebase_on_the_trunk_branch_itself
    assert_equal "#{WHEN}git pull --rebase origin main", line(trunk_tip(seen_at: NOW), branch: "main")
  end

  def test_should_merge_a_local_trunk
    assert_equal "Conflicts with develop in 2 files. When the task is done, integrate: git merge develop",
                 line(trunk_tip(seen_at: NOW, remote: nil, branch: "develop"), branch: "feat/cart")
  end

  def test_should_count_one_file_as_a_file
    assert_equal "Conflicts with origin/main in 1 file.",
                 FunCi::Agent::NextStep.line(trunk_tip(seen_at: NOW), ["a.rb"], branch: "main").split(" When").first
  end

  private

  def line(tip, branch:) = FunCi::Agent::NextStep.line(tip, ["a.rb", "b.rb"], branch: branch)
end
