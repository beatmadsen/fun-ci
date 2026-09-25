# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/end_to_end"

# AT-1.6: a newer commit on the branch cancels the run still going for an
# older one: every process of the old run ends, stage scripts included, the
# run is recorded cancelled, and its slot is free.
#
# The old run is a real `fun-ci trigger` process whose stages never finish.
# It gets one end of a pipe as fd 3, which every process it starts inherits,
# so reading that pipe to its end waits exactly until all of them are gone.
class TestStaleRunCancellation < Minitest::Test
  include EndToEnd

  FUN_CI = File.expand_path("../../../../exe/fun-ci", __dir__)

  def setup
    @project = GitProject.create
    @tmp = Dir.mktmpdir("stale-run")
    File.mkfifo(started)
    @old = commit_stages(fast: "echo started > #{started}; exec tail -f /dev/null", slow: "exec tail -f /dev/null")
    @new = commit_stages(fast: "true", slow: "true")
    cancel_old_run_with_new_one
  end

  def teardown
    [@project.dir, @tmp].each { |dir| FileUtils.rm_rf(dir) }
  end

  def test_the_old_run_is_recorded_cancelled
    assert_equal "cancelled", status_of(@old)
  end

  def test_the_old_run_s_slot_is_free
    assert(File.open(File.join(@project.common_dir, "fun-ci", "worktrees", "slot-0.lock")) do |lock|
      lock.flock(File::LOCK_EX | File::LOCK_NB)
    end)
  end

  private

  def started = File.join(@tmp, "started")
  def db_dir = File.join(@tmp, "fun-ci")

  def commit_stages(fast:, slow:)
    @project.write_stage_scripts { |stage| { "fast" => fast, "slow" => slow }.fetch(stage, "true") }
    @project.commit("#{fast} / #{slow}")
  end

  # Returns once every process of the old run has ended.
  def cancel_old_run_with_new_one
    all_gone, held = IO.pipe
    pid = start_old_run(held)
    File.read(started)
    trigger(@project, @new, db_dir: db_dir)
    all_gone.read
    Process.wait(pid)
  end

  def start_old_run(held)
    Process.spawn({ "TMPDIR" => @tmp }, RbConfig.ruby, FUN_CI, "trigger", @old, "main",
                  chdir: @project.dir, 3 => held, %i[out err] => File::NULL).tap { held.close }
  end

  def status_of(sha)
    db = FunCi::Persistence::Database.connection(File.join(db_dir, "db.sqlite3"))
    FunCi::Persistence::PipelineRun.find_by_commit(db, sha).first[:status]
  ensure
    db&.close
  end
end
