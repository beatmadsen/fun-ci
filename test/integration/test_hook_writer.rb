# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/hook_writer"
require "tmpdir"
require "stringio"

# Writing hooks into .git/hooks. What goes in them is HookScript's. HookWriter
# only needs .git/ to exist, so no repository is created.
class TestHookWriter < Minitest::Test
  FOREIGN_HOOK = "#!/bin/sh\n# husky managed hook\nnpx lint-staged\n"

  def setup
    @dir = Dir.mktmpdir("fun-ci-hook-test")
    @stdout = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_write_the_hook_s_script
    in_git_dir { install }

    assert_equal FunCi::Setup::HookScript.for("pre-commit"), File.read(hook_path)
  end

  def test_should_make_the_hook_executable
    in_git_dir { install }

    assert File.executable?(hook_path)
  end

  def test_should_create_the_hooks_directory_when_it_is_missing
    in_git_dir { install }

    assert File.exist?(hook_path)
  end

  def test_should_say_which_hook_it_installed
    in_git_dir { install }

    assert_equal "Installed pre-commit hook.\n", @stdout.string
  end

  def test_should_refuse_a_hook_type_it_does_not_manage
    in_git_dir { assert_equal 1, install("post-merge") }
  end

  def test_should_refuse_outside_a_git_repository
    assert_equal 1, install
  end

  def test_should_say_the_git_directory_is_missing
    install

    assert_match(/no \.git/, @stdout.string)
  end

  def test_should_leave_another_tool_s_hook_alone
    in_git_dir { existing_hook(FOREIGN_HOOK) && install }

    assert_equal FOREIGN_HOOK, File.read(hook_path)
  end

  def test_should_succeed_when_leaving_another_tool_s_hook_alone
    in_git_dir { existing_hook(FOREIGN_HOOK) && assert_equal(0, install) }
  end

  def test_should_say_it_left_another_tool_s_hook_alone
    in_git_dir { existing_hook(FOREIGN_HOOK) && install }

    assert_match(/already exists/, @stdout.string)
  end

  def test_should_replace_a_hook_it_wrote_before
    in_git_dir { existing_hook("#!/bin/sh\n# fun-ci-managed-hook\nold-fun-ci-trigger\n") && install }

    assert_equal FunCi::Setup::HookScript.for("pre-commit"), File.read(hook_path)
  end

  private

  def in_git_dir
    Dir.mkdir(File.join(@dir, ".git"))
    yield
  end

  def hook_path = File.join(@dir, ".git", "hooks", "pre-commit")

  def existing_hook(content)
    FileUtils.mkdir_p(File.dirname(hook_path))
    File.write(hook_path, content)
  end

  def install(hook_type = "pre-commit")
    FunCi::Setup::HookWriter.run(project_root: @dir, hook_type: hook_type, stdout: @stdout)
  end
end
