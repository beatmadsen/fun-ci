# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/persistence/state_dir"

# What fun-ci keeps can hold what masking missed, so only its user can read
# the state directory (why.md, "Masking secrets").
class TestStateDirMode < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    @umask = File.umask(0o022)
  end

  def teardown
    File.umask(@umask)
    FileUtils.remove_entry(@root)
  end

  def test_should_create_the_directory_readable_by_its_user_alone
    path = File.join(@root, "state", "fun-ci")
    FunCi::Persistence::StateDir.prepare(path)

    assert_equal 0o700, File.stat(path).mode & 0o777
  end

  def test_should_make_a_directory_that_already_exists_readable_by_its_user_alone
    path = File.join(@root, "fun-ci")
    Dir.mkdir(path, 0o755)
    FunCi::Persistence::StateDir.prepare(path)

    assert_equal 0o700, File.stat(path).mode & 0o777
  end
end
