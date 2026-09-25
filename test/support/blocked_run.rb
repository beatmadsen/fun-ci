# frozen_string_literal: true

require_relative "end_to_end"
require_relative "descendants"
require "fun_ci/console/board_data"

# A real `fun-ci trigger` run, in a process of its own, whose stage scripts
# can be parked: a script given `park(stage)` waits on a FIFO the test opens
# only after cancelling; one still alive then writes its stage to `outlived`
# and exits, so the run always ends and a failed cancel fails a test rather
# than hanging it. Descendants tells when every process of the run is gone.
# Expects @project and @tmp.
module BlockedRun
  include EndToEnd

  FUN_CI = File.expand_path("../../exe/fun-ci", __dir__)

  def create_blocked_project
    @project = GitProject.create
    @tmp = Dir.mktmpdir("blocked-run")
    [started, release].each { |fifo| File.mkfifo(fifo) }
  end

  def remove_blocked_project = [@project.dir, @tmp].each { |dir| FileUtils.rm_rf(dir) }

  def started = File.join(@tmp, "started")
  def release = File.join(@tmp, "release")
  def outlived = File.join(@tmp, "outlived")
  def db_dir = File.join(@tmp, "fun-ci")
  def say_started = "echo started > #{started}"
  def park(stage) = "read line < #{release}; echo #{stage} >> #{outlived}"

  def commit_stages(fast:, slow:)
    @project.write_stage_scripts { |stage| { "fast" => fast, "slow" => slow }.fetch(stage, "true") }
    @project.commit("#{fast} / #{slow}")
  end

  # Starts the run and returns once a stage script has said it started.
  def start_blocked_run(sha)
    Descendants.spawn({ "TMPDIR" => @tmp }, RbConfig.ruby, FUN_CI, "trigger", sha, "main",
                      chdir: @project.dir, %i[out err] => File::NULL).tap { File.read(started) }
  end

  # Lets whatever survived the cancel finish, and waits for the run to end.
  def release_and_wait(run)
    release_what_survived
    run.wait_for_all
  end

  # Opening a FIFO for writing without blocking fails when nothing reads it;
  # writing to it fails when its last reader was a script the cancel killed
  # after the open. Either way no script survived to release.
  def release_what_survived(after_open: -> {})
    File.open(release, File::WRONLY | File::NONBLOCK) do |fifo|
      after_open.call
      fifo.write("go\n")
    end
  rescue Errno::ENXIO, Errno::EPIPE
    nil
  end

  def status_of(sha) = with_db { |db| FunCi::Persistence::PipelineRun.find_by_commit(db, sha).first[:status] }
  def run_id_of(sha) = with_db { |db| FunCi::Persistence::PipelineRun.find_by_commit(db, sha).first[:id] }

  def slot_free?
    File.open(File.join(@project.common_dir, "fun-ci", "worktrees", "slot-0.lock")) do |lock|
      lock.flock(File::LOCK_EX | File::LOCK_NB)
    end
  end

  def with_db
    db = FunCi::Persistence::Database.connection(File.join(db_dir, "db.sqlite3"))
    yield db
  ensure
    db&.close
  end
end
