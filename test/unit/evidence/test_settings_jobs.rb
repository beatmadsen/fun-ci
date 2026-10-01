# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/settings"

# A daily or weekly job's own entries, under `jobs:` in the `evidence` key
# (acceptance-tests.md, AT-13.10). A job is known to evidence as `jobs/<name>`.
class TestEvidenceSettingsJobs < Minitest::Test
  SETTINGS = FunCi::Evidence::Settings

  def test_should_list_a_job_s_entries_after_those_for_every_stage
    raw = { "stages" => { "all" => [{ "use" => "a" }] }, "jobs" => { "soak" => [{ "use" => "b" }] } }

    assert_equal [{ "use" => "a" }, { "use" => "b" }], SETTINGS.new(raw).entries("jobs/soak")
  end

  def test_should_not_give_a_job_the_entries_of_a_stage_of_the_same_name
    raw = { "stages" => { "fast" => [{ "use" => "b" }] } }

    assert_empty SETTINGS.new(raw).entries("jobs/fast")
  end

  def test_should_not_give_a_stage_the_entries_of_a_job_of_the_same_name
    raw = { "jobs" => { "fast" => [{ "use" => "b" }] } }

    assert_empty SETTINGS.new(raw).entries("fast")
  end

  def test_should_know_the_jobs_setting
    assert_empty SETTINGS.new({ "jobs" => { "soak" => [{ "use" => "grep", "patterns" => ["x"] }] } }).errors
  end

  def test_should_report_each_job_entry_s_mistake_with_its_job
    assert_equal ["evidence.jobs.soak: unknown extractor 'nosuch'"],
                 SETTINGS.new({ "jobs" => { "soak" => [{ "use" => "nosuch" }] } }).errors
  end

  def test_should_report_jobs_that_are_not_a_mapping
    assert_equal ["evidence.jobs must be a mapping of job to entries"], SETTINGS.new({ "jobs" => ["soak"] }).errors
  end
end
