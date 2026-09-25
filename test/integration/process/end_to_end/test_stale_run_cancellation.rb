# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/end_to_end"

# AT-1.6: a newer commit on the branch cancels the run still going for an
# older one: every process of the old run ends, stage scripts included, the
# run is recorded cancelled, and its slot is free.
#
# The old run is a real `fun-ci trigger` process. Its fast and slow scripts
# wait on a FIFO the test opens once the new run has finished; a script
# still alive then writes to `outlived` and exits, so the old run ends
# whether or not cancelling worked. It gets one end of a pipe as fd 3, which
# every process it starts inherits, so reading that pipe to its end waits
# exactly until all of them are gone.
class TestStaleRunCancellation < Minitest::Test
  include EndToEnd

  FUN_CI = File.expand_path("../../../../exe/fun-ci", __dir__)

  def setup
    @project = GitProject.create
    @tmp = Dir.mktmpdir("stale-run")
    [started, release].each { |fifo| File.mkfifo(fifo) }
    @old = commit_stages(fast: "echo started > #{started}\n#{wait_then_note("fast")}", slow: wait_then_note("slow"))
    @new = commit_stages(fast: "true", slow: "true")
    cancel_old_run_with_new_one
  end

  def teardown
    [@project.dir, @tmp].each { |dir| FileUtils.rm_rf(dir) }
  end

  def test_no_stage_script_of_the_old_run_outlives_the_cancel
    refute File.exist?(outlived)
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
  def release = File.join(@tmp, "release")
  def outlived = File.join(@tmp, "outlived")
  def db_dir = File.join(@tmp, "fun-ci")
  def wait_then_note(stage) = "read line < #{release}; echo #{stage} >> #{outlived}"

  def commit_stages(fast:, slow:)
    @project.write_stage_scripts { |stage| { "fast" => fast, "slow" => slow }.fetch(stage, "true") }
    @project.commit("#{fast} / #{slow}")
  end

  def cancel_old_run_with_new_one
    all_gone, held = IO.pipe
    old_pid = start_old_run(held)
    File.read(started)
    trigger(@project, @new, db_dir: db_dir)
    release_what_survived_and_wait(all_gone)
    Process.wait(old_pid)
  end

  def start_old_run(held)
    Process.spawn({ "TMPDIR" => @tmp }, RbConfig.ruby, FUN_CI, "trigger", @old, "main",
                  chdir: @project.dir, 3 => held, %i[out err] => File::NULL).tap { held.close }
  end

  def release_what_survived_and_wait(all_gone)
    release_what_survived
    all_gone.read
  end

  # Opening a FIFO for writing without blocking fails when nothing reads it.
  def release_what_survived
    File.open(release, File::WRONLY | File::NONBLOCK) { |fifo| fifo.write("go\n") }
  rescue Errno::ENXIO
    nil
  end

  def status_of(sha)
    db = FunCi::Persistence::Database.connection(File.join(db_dir, "db.sqlite3"))
    FunCi::Persistence::PipelineRun.find_by_commit(db, sha).first[:status]
  ensure
    db&.close
  end
end
