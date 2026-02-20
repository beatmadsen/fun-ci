# frozen_string_literal: true

require_relative "../test_helper"
require_relative "trigger_cli_client"

# Acceptance tests for project configuration validation and script invocation.
#
# Covers: missing .fun-ci/ folder, missing individual scripts,
# non-executable scripts, and script invocation contract
# (commit hash passed as $1 to each stage script).

class TestTriggerCliProjectConfiguration < Minitest::Test
  def setup
    @client = TriggerCliClient.new
  end

  def teardown
    @client.close
  end

  # --- Missing .fun-ci/ folder ---

  def test_should_exit_gracefully_when_no_fun_ci_folder_found
    @client.trigger_without_fun_ci_folder(commit_hash: "abc1234", branch: "main")
    assert_equal 0, @client.exit_code, "Should exit 0 when no .fun-ci/ folder found"
    assert_match(/No \.fun-ci\/ folder found/i, @client.stdout, "Should mention missing folder")
    assert_match(/build\.sh.*fast\.sh.*slow\.sh/m, @client.stdout, "Should suggest creating scripts")
  end

  # --- Missing individual hook scripts ---

  def test_should_exit_gracefully_when_build_script_is_missing
    @client.trigger_with_missing_script(commit_hash: "abc1234", branch: "main", missing_script: "build.sh")
    assert_equal 0, @client.exit_code, "Should exit 0 when build.sh is missing"
    assert_match(/\.fun-ci\/build\.sh is not/, @client.stdout, "Should mention missing build.sh")
  end

  def test_should_exit_gracefully_when_fast_script_is_missing
    @client.trigger_with_missing_script(commit_hash: "abc1234", branch: "main", missing_script: "fast.sh")
    assert_equal 0, @client.exit_code, "Should exit 0 when fast.sh is missing"
    assert_match(/\.fun-ci\/fast\.sh is not/, @client.stdout, "Should mention missing fast.sh")
  end

  def test_should_exit_gracefully_when_slow_script_is_missing
    @client.trigger_with_missing_script(commit_hash: "abc1234", branch: "main", missing_script: "slow.sh")
    assert_equal 0, @client.exit_code, "Should exit 0 when slow.sh is missing"
    assert_match(/\.fun-ci\/slow\.sh is not/, @client.stdout, "Should mention missing slow.sh")
  end

  # --- Hook scripts not executable ---

  def test_should_exit_gracefully_when_hook_script_is_not_executable
    @client.trigger_with_nonexecutable_script(commit_hash: "abc1234", branch: "main", script: "fast.sh")
    assert_equal 0, @client.exit_code, "Should exit 0 when script not executable"
    assert_match(/\.fun-ci\/fast\.sh is not executable/, @client.stdout, "Should mention non-executable script")
  end
end

class TestTriggerCliHookScriptInvocation < Minitest::Test
  def setup
    @client = TriggerCliClient.new
  end

  def teardown
    @client.close
  end

  def test_should_invoke_build_script_with_commit_hash_as_first_argument
    @client.trigger(commit_hash: "abc1234", branch: "main")
    args = @client.script_arguments_for("build.sh")
    refute_nil args, "build.sh should have been invoked"
    assert_equal "abc1234", args.first, "build.sh should receive commit hash as $1"
  end

  def test_should_invoke_fast_script_with_commit_hash_as_first_argument
    @client.trigger(commit_hash: "abc1234", branch: "main")
    args = @client.script_arguments_for("fast.sh")
    refute_nil args, "fast.sh should have been invoked"
    assert_equal "abc1234", args.first, "fast.sh should receive commit hash as $1"
  end

  def test_should_invoke_slow_script_with_commit_hash_as_first_argument
    client = TriggerCliClient.new(
      background_launcher: SYNC_LAUNCHER
    )
    client.trigger(commit_hash: "abc1234", branch: "main")
    args = client.script_arguments_for("slow.sh")
    refute_nil args, "slow.sh should have been invoked"
    assert_equal "abc1234", args.first, "slow.sh should receive commit hash as $1"
  ensure
    client&.close
  end

  def test_should_treat_nonzero_exit_from_build_script_as_failure
    @client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "build.sh" => "exit 1" })
    refute_equal 0, @client.exit_code, "Should fail when build fails"
    assert_match(/Build failed/i, @client.stdout, "Should mention build failure")
  end

  def test_should_treat_zero_exit_from_fast_script_as_pass
    @client.trigger(commit_hash: "abc1234", branch: "main")
    assert_equal 0, @client.exit_code, "Should pass when fast suite passes"
  end
end
