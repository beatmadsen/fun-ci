# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/state_dir"

class TestStateDir < Minitest::Test
  STATE_DIR = FunCi::Persistence::StateDir

  def test_should_be_under_the_xdg_state_home_when_one_is_set
    assert_equal "/xdg/state/fun-ci", STATE_DIR.path("XDG_STATE_HOME" => "/xdg/state", "HOME" => "/home/me")
  end

  def test_should_be_under_the_home_directory_without_an_xdg_state_home
    assert_equal "/home/me/.local/state/fun-ci", STATE_DIR.path("HOME" => "/home/me")
  end

  def test_should_treat_an_empty_xdg_state_home_as_unset
    assert_equal "/home/me/.local/state/fun-ci", STATE_DIR.path("XDG_STATE_HOME" => "", "HOME" => "/home/me")
  end
end
