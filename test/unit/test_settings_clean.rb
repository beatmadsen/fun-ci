# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/settings"

# Which git-ignored outputs a slot loses when it moves to a commit that doesn't
# descend from its last one, from .fun-ci/config's `clean` (architecture.md,
# Worktree pool); one that is wrong takes the default, and check names it.
class TestSettingsClean < Minitest::Test
  def test_should_clean_nothing_when_nothing_says_to
    assert_empty settings(nil).clean
  end

  def test_should_clean_the_paths_given
    assert_equal %w[public/assets dist], settings("clean: [public/assets, dist]\n").clean
  end

  def test_should_clean_nothing_when_given_no_list
    assert_empty settings("clean: public/assets\n").clean
  end

  def test_should_clean_nothing_when_a_path_leaves_the_project
    assert_empty settings("clean: [dist, ../elsewhere]\n").clean
  end

  def test_should_clean_nothing_when_a_path_is_absolute
    assert_empty settings("clean: [/tmp]\n").clean
  end

  def test_should_name_a_clean_setting_it_cannot_use
    assert_equal [".fun-ci/config: clean must be a list of paths inside the project, such as [public/assets], " \
                  "not \"public/assets\""], settings("clean: public/assets\n").errors
  end

  def test_should_find_nothing_wrong_with_a_list_of_paths
    assert_empty settings("clean: [public/assets]\n").errors
  end

  private

  def settings(text) = FunCi::Setup::Settings.new(text)
end
