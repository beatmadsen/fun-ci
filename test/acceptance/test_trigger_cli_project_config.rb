# frozen_string_literal: true

require_relative "trigger_cli_shared"

# A project whose .fun-ci/ is missing or incomplete never blocks a commit:
# the trigger says what is wrong and exits 0.
class TestTriggerCliProjectConfiguration < Minitest::Test
  def setup
    @client = TriggerCliClient.open
  end

  def teardown
    @client.close
  end

  def test_should_exit_zero_when_no_fun_ci_folder_found
    @client.trigger_without_fun_ci_folder(commit_hash: "abc1234", branch: "main")

    assert_equal 0, @client.exit_code
  end

  def test_should_suggest_creating_the_scripts_when_no_fun_ci_folder_found
    @client.trigger_without_fun_ci_folder(commit_hash: "abc1234", branch: "main")

    assert_match(/lint\.sh.*build\.sh.*fast\.sh.*slow\.sh/m, @client.stdout)
  end

  %w[lint build fast slow].each do |stage|
    define_method(:"test_should_exit_zero_when_#{stage}_script_is_missing") do
      @client.trigger_with_missing_script(commit_hash: "abc1234", branch: "main", missing_script: "#{stage}.sh")

      assert_equal 0, @client.exit_code
    end

    define_method(:"test_should_name_the_missing_#{stage}_script") do
      @client.trigger_with_missing_script(commit_hash: "abc1234", branch: "main", missing_script: "#{stage}.sh")

      assert_match(%r{\.fun-ci/#{stage}\.sh is not}, @client.stdout)
    end
  end

  def test_should_exit_zero_when_a_script_is_not_executable
    @client.trigger_with_nonexecutable_script(commit_hash: "abc1234", branch: "main", script: "fast.sh")

    assert_equal 0, @client.exit_code
  end

  def test_should_name_the_script_that_is_not_executable
    @client.trigger_with_nonexecutable_script(commit_hash: "abc1234", branch: "main", script: "fast.sh")

    assert_match(%r{\.fun-ci/fast\.sh is not executable}, @client.stdout)
  end
end
