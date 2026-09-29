# frozen_string_literal: true

require_relative "../test_helper"
require "yaml"

# The checks that need Docker and the network run weekly, each in a job of
# its own so one failing doesn't hide the other: the presets against their
# tools' newest releases (AT-10.20), and the scripts `fun-ci init` writes on
# the presets' recorded projects (AT-10.21).
class TestEvidencePresetsWorkflow < Minitest::Test
  WORKFLOW = File.expand_path("../../.github/workflows/evidence-presets.yml", __dir__)

  def test_should_check_the_presets_against_their_tools_newest_releases
    assert_includes commands("presets"), "ruby script/check_evidence_presets.rb"
  end

  def test_should_check_init_s_scripts_on_the_presets_recorded_projects
    assert_includes commands("init-templates"), "ruby script/check_init_templates.rb"
  end

  private

  def commands(job) = Array(YAML.safe_load_file(WORKFLOW).dig("jobs", job, "steps")).filter_map { |step| step["run"] }
end
