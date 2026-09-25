# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/hook_writer"
require "tmpdir"
require "stringio"

module HookWriterTemplateHelpers
  private

  def written_hook(hook_type)
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      FunCi::Setup::HookWriter.run(project_root: dir, hook_type: hook_type, stdout: StringIO.new)
      File.read(File.join(dir, ".git", "hooks", hook_type))
    end
  end
end

class TestHookWriterPreCommitTemplate < Minitest::Test
  include HookWriterTemplateHelpers

  def test_pre_commit_hook_should_include_no_validate_flag
    assert_match(/--no-validate/, written_hook("pre-commit"), "Pre-commit hook should include --no-validate flag")
  end

  def test_pre_commit_hook_should_use_unified_command_name
    assert_match(/fun-ci trigger/, written_hook("pre-commit"), "Pre-commit hook should use 'fun-ci trigger' command")
  end
end

class TestHookWriterPrePushTemplate < Minitest::Test
  include HookWriterTemplateHelpers

  def test_pre_push_hook_should_not_include_no_validate_flag
    refute_match(/--no-validate/, written_hook("pre-push"), "Pre-push hook should NOT include --no-validate flag")
  end

  def test_pre_push_hook_should_use_unified_command_name
    assert_match(/fun-ci trigger/, written_hook("pre-push"), "Pre-push hook should use 'fun-ci trigger' command")
  end
end
