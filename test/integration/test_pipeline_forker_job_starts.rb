# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/pipeline_forker"
require "fun_ci/persistence/database"
require "tmpdir"

# The post-commit hook's run starts each due job at its turn (Jobs::Schedule,
# AT-13.28): the forker hands each job's start to what starts it. That a
# real job waits for its turn is test_job_run_scheduled.rb's.
class TestPipelineForkerJobStarts < Minitest::Test
  include DatabaseTestSetup

  # Keeps what it is asked to start, and starts nothing.
  Starts = Struct.new(:calls) do
    def start(job, _commit, at:) = calls << [job.name, at]
  end

  def setup
    setup_test_db
    @project = File.join(@dir, "project")
    %w[daily/fuzz.sh weekly/soak.sh].each { |script| write(".fun-ci/#{script}") }
  end

  def teardown = teardown_test_db

  # Two jobs share a day: twelve hours each.
  def test_should_hand_the_second_due_job_a_start_a_spacing_after_the_first
    starts = Starts.new([])
    Dir.chdir(@project) do
      FunCi::Pipeline::PipelineForker.start_due_jobs(FunCi::Pipeline::Commit.new(sha: "a" * 40, branch: "main"),
                                                     @db.filename("main"), fork: starts)
    end

    assert_equal 43_200, starts.calls.last.last - starts.calls.first.last
  end

  private

  def write(path)
    full = File.join(@project, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, "#!/bin/sh\n")
    File.chmod(0o755, full)
  end
end
