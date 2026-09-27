# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require "tmpdir"
require "fun_ci/agent/live_pipeline"

# `wait` starts a run for a commit that has none as the post-commit hook
# does (AT-9.11): `fun-ci trigger --background SHA BRANCH` in the project, a
# process of its own (here a stand-in that records what it was asked). What
# that command runs and records is pinned in the acceptance lane.
class TestLivePipelineStarts < Minitest::Test
  include ProcessDeadline

  def setup
    @project = File.realpath(Dir.mktmpdir("project"))
    %w[lint build fast slow].each { |stage| script(".fun-ci/#{stage}.sh", "exit 0") }
    script("fun-ci", %(echo "$(pwd -P) $*" > #{File.join(@project, "asked")}))
    within_deadline { live_pipeline.start("abc1234", "main") }
  end

  def teardown = FileUtils.rm_rf(@project)

  def test_should_start_the_pipeline_in_the_background_in_the_project
    assert_equal "#{@project} trigger --background abc1234 main", File.read(File.join(@project, "asked")).chomp
  end

  private

  # Run through sh, since macOS scans a freshly written executable on its first exec.
  def live_pipeline = FunCi::Agent::LivePipeline.new(@project, command: ["/bin/sh", File.join(@project, "fun-ci")])

  def script(path, body)
    File.join(@project, path).then do |full|
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, "#!/bin/sh\n#{body}\n")
      File.chmod(0o755, full)
    end
  end
end
