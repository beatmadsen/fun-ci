# frozen_string_literal: true

require_relative "../test_helper"

# AT-0.4: the confinement guard only protects a run it is installed in.
class TestConfinementGuardInstalled < Minitest::Test
  def test_should_have_the_confinement_guard_installed
    assert_predicate ConfinementGuard, :installed?
  end

  def test_should_point_dir_tmpdir_at_the_run_s_own_temp_root
    assert_equal ConfinementGuard.root, File.realpath(Dir.tmpdir)
  end
end
