# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/setup_checker"
require "stringio"

# `fun-ci check`: report what ProjectConfig found wrong, or that all is well.
class TestSetupChecker < Minitest::Test
  Config = Struct.new(:validate, :settings_errors, :evidence_errors, :job_errors, :jobs, :presets, :any_project_presets,
                      keyword_init: true)
  Job = Data.define(:name, :cadence)
  Hooks = Struct.new(:warnings)
  Trunk = Struct.new(:lines)
  PROBLEMS = [".fun-ci/lint.sh is not found", ".fun-ci/fast.sh is not executable"].freeze

  def test_should_fail_when_the_project_has_problems
    assert_equal 1, check(PROBLEMS)
  end

  def test_should_list_each_problem_on_its_own_line
    check(PROBLEMS)

    assert_equal PROBLEMS, @stdout.string.lines(chomp: true)
  end

  def test_should_pass_when_the_project_has_no_problems
    assert_equal 0, check([])
  end

  def test_should_say_the_project_is_configured_when_it_has_no_problems
    check([])

    assert_equal "All OK. The project is configured.\n", @stdout.string
  end

  def test_should_still_pass_with_only_warnings
    assert_equal 0, check([], warnings: ["hook calls fun-ci"])
  end

  def test_should_print_each_warning_after_the_verdict
    check([], warnings: ["hook calls fun-ci"])

    assert_equal "All OK. The project is configured.\nWarning: hook calls fun-ci\n", @stdout.string
  end

  def test_should_name_the_presets_that_will_run_for_the_project
    check([], presets: %w[rspec minitest])

    assert_equal "All OK. The project is configured.\nEvidence presets for this project: rspec, minitest\n",
                 @stdout.string
  end

  def test_should_name_the_presets_that_read_any_project_s_output_apart
    check([], any_project_presets: %w[ecs shellcheck])

    assert_equal "All OK. The project is configured.\nEvidence presets for any project's output: ecs, shellcheck\n",
                 @stdout.string
  end

  def test_should_list_a_mistake_in_the_evidence_configuration_as_a_problem
    check([], evidence_errors: ["evidence.stages.fast: unknown extractor 'nosuch'"])

    assert_equal "evidence.stages.fast: unknown extractor 'nosuch'\n", @stdout.string
  end

  def test_should_say_what_the_trunk_is_after_the_verdict
    check([], trunk: ["Trunk: origin/main (origin's default branch)."])

    assert_equal "All OK. The project is configured.\nTrunk: origin/main (origin's default branch).\n", @stdout.string
  end

  def test_should_still_pass_when_no_trunk_is_found
    assert_equal 0, check([], trunk: ["Warning: no trunk found"])
  end

  def test_should_list_a_job_that_cannot_run_as_a_problem
    check([], job_errors: [".fun-ci/daily/mutation.sh is not executable"])

    assert_equal ".fun-ci/daily/mutation.sh is not executable\n", @stdout.string
  end

  def test_should_fail_when_a_job_cannot_run
    assert_equal 1, check([], job_errors: [".fun-ci/daily/mutation.sh is not executable"])
  end

  def test_should_fail_when_the_config_has_a_mistake
    assert_equal 1, check([], settings_errors: [".fun-ci/config: worktree_slots must be a whole number above 0, not 0"])
  end

  def test_should_list_each_job_with_how_often_it_runs
    check([], jobs: [Job.new(name: "mutation", cadence: "daily"), Job.new(name: "soak", cadence: "weekly")])

    assert_equal "All OK. The project is configured.\nJobs: mutation (daily), soak (weekly)\n", @stdout.string
  end

  private

  def check(problems, warnings: [], trunk: [], **given)
    @stdout = StringIO.new
    config = Config.new(validate: problems, settings_errors: [], evidence_errors: [], job_errors: [], jobs: [],
                        presets: [], any_project_presets: [], **given)
    FunCi::Setup::SetupChecker.new(config: config, hooks: Hooks.new(warnings), stdout: @stdout, trunk: Trunk.new(trunk))
                              .run
  end
end
