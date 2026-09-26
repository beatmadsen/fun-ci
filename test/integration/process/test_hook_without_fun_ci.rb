# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/setup/hook_script"
require "open3"
require "tmpdir"

# A git hook is a safety net, not a gate: when fun-ci isn't installed, the
# push goes ahead and the hook says why there was no CI (design.md, Reliable).
class TestHookWithoutFunCi < Minitest::Test
  SYSTEM_PATH = "/usr/bin:/bin"

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_should_let_the_push_proceed_when_fun_ci_is_not_installed
    _output, status = run_hook(path: SYSTEM_PATH)

    assert_equal 0, status.exitstatus
  end

  def test_should_say_how_to_install_fun_ci_when_it_is_missing
    output, _status = run_hook(path: SYSTEM_PATH)

    assert_match(/fun-ci is not installed.*gem install fun_ci/m, output)
  end

  def test_should_block_the_push_when_the_installed_fun_ci_fails
    fake_fun_ci(exit_status: 3)

    _output, status = run_hook(path: "#{@dir}/bin:#{SYSTEM_PATH}")

    assert_equal 3, status.exitstatus
  end

  private

  def run_hook(path:)
    hook = File.join(@dir, "pre-push")
    File.write(hook, FunCi::Setup::HookScript.for("pre-push"))
    Open3.capture2e({ "PATH" => path }, "/bin/sh", hook, chdir: @dir)
  end

  def fake_fun_ci(exit_status:)
    FileUtils.mkdir_p(File.join(@dir, "bin"))
    File.write(File.join(@dir, "bin", "fun-ci"), "#!/bin/sh\nexit #{exit_status}\n")
    File.chmod(0o755, File.join(@dir, "bin", "fun-ci"))
  end
end
