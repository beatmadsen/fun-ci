# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/legacy_hooks"
require "tmpdir"
require "stringio"

# AT-1.9: fun-ci 1.x ran the background pipeline from pre-commit. Upgrading
# removes the pre-commit hook fun-ci wrote, leaves anyone else's alone, and
# warns about one that still calls fun-ci itself.
class TestLegacyHooks < Minitest::Test
  FUN_CI_1X = "#!/bin/sh\n# fun-ci-managed-hook\nfun-ci trigger --no-validate \"$COMMIT\" \"$BRANCH\"\n"
  HAND_WRITTEN = "#!/bin/sh\nnpx lint-staged\nfun-ci trigger --no-validate $(git rev-parse HEAD) main\n"
  UNRELATED = "#!/bin/sh\nnpx lint-staged\n"

  def setup
    @dir = Dir.mktmpdir("legacy-hooks")
    FileUtils.mkdir_p(File.join(@dir, ".git", "hooks"))
    @stdout = StringIO.new
  end

  def teardown = FileUtils.rm_rf(@dir)

  def test_should_remove_the_pre_commit_hook_fun_ci_wrote
    pre_commit(FUN_CI_1X)
    legacy.remove(@stdout)

    refute File.exist?(hook)
  end

  def test_should_say_it_removed_fun_ci_s_pre_commit_hook
    pre_commit(FUN_CI_1X)
    legacy.remove(@stdout)

    assert_includes @stdout.string, "Removed fun-ci's 1.x pre-commit hook"
  end

  def test_should_leave_someone_else_s_pre_commit_hook_alone
    pre_commit(HAND_WRITTEN)
    legacy.remove(@stdout)

    assert_equal HAND_WRITTEN, File.read(hook)
  end

  def test_should_warn_about_someone_else_s_pre_commit_hook_that_calls_fun_ci
    pre_commit(HAND_WRITTEN)

    assert_equal [".git/hooks/pre-commit calls fun-ci, which now runs after the commit: " \
                  "take fun-ci out of it and run `fun-ci install-hooks`"], legacy.warnings
  end

  def test_should_not_warn_about_a_pre_commit_hook_that_has_nothing_to_do_with_fun_ci
    pre_commit(UNRELATED)

    assert_empty legacy.warnings
  end

  def test_should_not_warn_without_a_pre_commit_hook
    assert_empty legacy.warnings
  end

  private

  def legacy = FunCi::Setup::LegacyHooks.new(@dir)
  def hook = File.join(@dir, ".git", "hooks", "pre-commit")
  def pre_commit(script) = File.write(hook, script)
end
