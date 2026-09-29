# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require_relative "../support/evidence_fixtures"
require "fun_ci/evidence/presets"
require "json"

# Presets for the popular stacks (acceptance-tests.md, AT-10.20): the fast
# suite of a project with a tool's marker files prints that tool's recorded
# failing run, and with no configuration its preset is chosen and picks out
# what its recording expects.
class TestAgentWhyEveryPreset < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"

  def teardown = @pipeline.close

  FunCi::Evidence::Presets.all.each do |preset|
    define_method("test_#{preset.name.tr("-", "_")}_is_chosen_for_its_tool_s_failing_run_and_picks_out_its_failures") do
      fixture = EvidenceFixtures.named(preset.name)
      run_fast_suite_printing(fixture.output, preset.markers.first)

      assert_equal fixture.expected.fetch("excerpts"), excerpts_of("#{preset.use}:#{preset.name}")
    end
  end

  private

  def run_fast_suite_printing(output, marker)
    @pipeline = TriggerCliClient.open(command_runner: fast_suite_printing(output))
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    write_marker(marker)
    @pipeline.trigger(commit_hash: SHA, branch: "main")
  end

  def fast_suite_printing(output)
    ->(cmd, &) { cmd.include?("fast.sh") ? [output, FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)] }
  end

  # A marker is a path or a glob, or a path and a text the file must hold;
  # a glob's file is named as a project would name it.
  def write_marker(marker)
    return unless marker

    path, text = marker.is_a?(String) ? [marker.sub("*", "Shop"), ""] : marker.values_at("path", "contains")
    FileUtils.mkdir_p(File.dirname(File.join(@pipeline.project_dir, path)))
    File.write(File.join(@pipeline.project_dir, path), text)
  end

  def excerpts_of(extractor)
    @agent.why("--json")
    excerpts = JSON.parse(@agent.stdout).dig("evidence", "excerpts")
    excerpts.select { |excerpt| excerpt["extractor"] == extractor }.map { |excerpt| excerpt["location"] }
  end
end
