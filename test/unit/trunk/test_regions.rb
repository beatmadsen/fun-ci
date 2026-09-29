# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/trunk/regions"

# The conflicted regions of a file as a merge leaves it, with the lines around them
# (docs/trunk-conflicts.md, why REV trunk).
class TestRegions < Minitest::Test
  CONFLICT = "<<<<<<< ours\nmine\n=======\ntheirs\n>>>>>>> trunk\n"

  def test_should_take_a_conflict_with_three_lines_either_side
    text = "#{(1..5).map { |n| "a#{n}\n" }.join}#{CONFLICT}#{(1..5).map { |n| "b#{n}\n" }.join}"

    assert_equal([[3, 13]], regions(text).map { |region| [region.first, region.last] })
  end

  def test_should_number_each_line_as_the_file_does
    assert_equal [1, "<<<<<<< ours"], regions(CONFLICT).first.lines.first
  end

  def test_should_join_conflicts_whose_surroundings_touch
    text = "#{CONFLICT}x\n#{CONFLICT}"

    assert_equal 1, regions(text).size
  end

  def test_should_keep_conflicts_far_apart_apart
    text = "#{CONFLICT}#{(1..7).map { |n| "x#{n}\n" }.join}#{CONFLICT}"

    assert_equal 2, regions(text).size
  end

  def test_should_find_no_region_in_a_file_without_markers
    assert_empty regions("a\nb\n")
  end

  private

  def regions(text) = FunCi::Trunk::Regions.of(text)
end
