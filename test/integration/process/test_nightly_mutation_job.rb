# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/body_script"
require "json"
require "open3"
require "time"

# This repository's daily job .fun-ci/daily/nightly-mutation.sh: how the
# latest finished run of the nightly mutation workflow went, read through a
# stand-in for gh, which prints the runs a test gives it.
class TestNightlyMutationJob < Minitest::Test
  JOB = File.expand_path("../../../.fun-ci/daily/nightly-mutation.sh", __dir__)
  URL = "https://github.com/beatmadsen/fun-ci/actions/runs/36840610614"

  def setup
    @dir = Dir.mktmpdir("nightly-mutation")
  end

  def teardown = FileUtils.rm_rf(@dir)

  def test_should_pass_when_the_latest_nightly_run_passed_today
    assert finished_run("success", hours_ago: 9).success?
  end

  def test_should_fail_when_the_latest_nightly_run_failed
    refute finished_run("failure", hours_ago: 9).success?
  end

  def test_should_say_where_the_latest_nightly_run_is
    finished_run("failure", hours_ago: 9)

    assert_includes @output, URL
  end

  # GitHub turns a schedule off in a repository that sees no activity for 60 days.
  def test_should_fail_when_no_nightly_run_finished_in_two_days
    refute finished_run("success", hours_ago: 49).success?
  end

  def test_should_fail_when_no_nightly_run_finished_yet
    refute job_with_gh("echo '[]'").success?
  end

  def test_should_fail_when_gh_cannot_list_the_runs
    refute job_with_gh("echo 'not logged in' >&2; exit 4").success?
  end

  def test_should_ask_gh_for_the_latest_finished_run_of_the_mutation_workflow
    finished_run("success", hours_ago: 9)

    assert_equal "run list --workflow mutation.yml --status completed --limit 1 --json conclusion,createdAt,url",
                 File.read(File.join(@dir, "asked")).strip
  end

  private

  def finished_run(conclusion, hours_ago:)
    run = { conclusion: conclusion, createdAt: (Time.now - (hours_ago * 3600)).utc.iso8601, url: URL }
    job_with_gh("cat <<'JSON'\n#{JSON.generate([run])}\nJSON")
  end

  # The job, with a gh that records what it was asked and then runs `body`.
  def job_with_gh(body)
    bin = FileUtils.mkdir_p(File.join(@dir, "bin")).first
    BodyScript.write(File.join(bin, "gh"), "echo \"$*\" > '#{File.join(@dir, "asked")}'\n#{body}")
    @output, status = Open3.capture2e({ "PATH" => "#{bin}:#{ENV.fetch("PATH")}" }, JOB)
    status
  end
end
