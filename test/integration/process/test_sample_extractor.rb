# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require "tmpdir"
require "fun_ci/evidence/command_runner"
require "fun_ci/evidence/command_output"

# The sample extractor in contract/evidence/ is a shell script, so what it
# prints was not written by the Ruby that reads it.
class TestSampleExtractor < Minitest::Test
  include ProcessDeadline

  CONTRACT = File.expand_path("../../../contract/evidence", __dir__)

  def setup = @dir = Dir.mktmpdir
  def teardown = FileUtils.remove_entry(@dir)

  def test_should_read_what_a_shell_script_extractor_prints_from_the_context_it_is_given
    assert_equal [{ name: "stage", value: "fast" }], FunCi::Evidence::CommandOutput.json(sample_output).facts
  end

  private

  def sample_output
    runner = FunCi::Evidence::CommandRunner.new(dir: @dir, scratch: @dir)
    within_deadline do
      runner.call("sh #{File.join(CONTRACT, "sample-extractor.sh")}",
                  stdin: File.read(File.join(CONTRACT, "context.json")), seconds: 10)
    end.stdout
  end
end
