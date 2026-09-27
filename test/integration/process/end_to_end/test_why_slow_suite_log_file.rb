# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/end_to_end"

# The whole of fun-ci why through the real CLI (why.md, "Testing it"): a
# real slow suite, run in its forked child in a worktree slot, fails with its
# cause only in a log file, and an agent reads the cause back.
class TestWhySlowSuiteLogFile < Minitest::Test
  include EndToEnd

  CONFIG = <<~YAML
    evidence:
      stages:
        slow:
          - use: log-file
            path: log/test.log
            grep: ["ERROR"]
  YAML

  def setup
    @project = GitProject.create
    @project.write_stage_scripts { |stage| stage == "slow" ? slow_suite : "true" }
    @project.write(".fun-ci/config", CONFIG)
    @project.write(".gitignore", "log/\n")
    @sha = @project.commit("Add stage scripts")
    @db_dir = Dir.mktmpdir("why-e2e")
    trigger(@project, @sha, db_dir: @db_dir)
  end

  def teardown = [@project.dir, @db_dir].each { |dir| FileUtils.rm_rf(dir) }

  def test_should_show_the_cause_the_slow_suite_wrote_only_to_its_log
    why("--need", "all")

    assert_includes @stdout.string, "  ERROR payment gateway refused the charge\n"
  end

  private

  def slow_suite
    "mkdir -p log; echo 'INFO starting' >> log/test.log; " \
      "echo 'ERROR payment gateway refused the charge' >> log/test.log; echo 'tests failed'; exit 1"
  end

  def why(*args)
    @stdout = StringIO.new
    io = FunCi::Pipeline::Io.new(stdout: @stdout, stderr: @stdout)
    Dir.chdir(@project.dir) { FunCi::Cli.run(["why", *args], io: io, db_dir: @db_dir) }
  end
end
