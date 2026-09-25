# frozen_string_literal: true

require_relative "../../../acceptance/trigger_cli_shared"

# The contract with a project's stage scripts, run as real processes: each
# gets the commit hash as $1, and its exit status decides pass or fail.
class TestHookScriptInvocation < Minitest::Test
  def setup
    @client = TriggerCliClient.open(background_launcher: SYNC_LAUNCHER)
  end

  def teardown
    @client.close
  end

  %w[lint build fast slow].each do |stage|
    define_method(:"test_should_invoke_#{stage}_script_with_commit_hash_as_first_argument") do
      @client.trigger(commit_hash: "abc1234", branch: "main")

      assert_equal ["abc1234"], @client.script_arguments_for("#{stage}.sh")
    end
  end

  def test_should_treat_nonzero_exit_from_build_script_as_failure
    @client.trigger(commit_hash: "abc1234", branch: "main", scripts: { "build.sh" => "exit 1" })

    refute_equal 0, @client.exit_code
  end

  def test_should_say_the_build_failed_when_its_script_exits_nonzero
    @client.trigger(commit_hash: "abc1234", branch: "main", scripts: { "build.sh" => "exit 1" })

    assert_match(/Build failed/, @client.stdout)
  end

  def test_should_treat_zero_exit_from_every_script_as_pass
    @client.trigger(commit_hash: "abc1234", branch: "main")

    assert_equal 0, @client.exit_code
  end
end
