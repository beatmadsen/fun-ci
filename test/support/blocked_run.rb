# frozen_string_literal: true

require_relative "end_to_end"
require "fun_ci/tui/board_data"

# A real `fun-ci trigger` run, in a process of its own, whose stage scripts
# can be parked: a script given `park(stage)` waits on a FIFO the test opens
# only after cancelling; one still alive then writes its stage to `outlived`
# and exits, so the run always ends and a failed cancel fails a test rather
# than hanging it. The run gets one end of a pipe as fd 3, which every
# process it starts inherits, so reading that pipe to its end waits exactly
# until all of them are gone. Expects @project and @tmp.
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

  # Starts the run and returns once a stage script has said it started, with
  # the run's pid and the reading end of its pipe.
  def start_blocked_run(sha)
    all_gone, held = IO.pipe
    pid = Process.spawn({ "TMPDIR" => @tmp }, RbConfig.ruby, FUN_CI, "trigger", sha, "main",
                        chdir: @project.dir, 3 => held, %i[out err] => File::NULL)
    held.close
    File.read(started)
    [pid, all_gone]
  end

  # Lets whatever survived the cancel finish, and waits for the run to end.
  def release_and_wait(pid, all_gone)
    release_what_survived
    all_gone.read
    Process.wait(pid)
  end

  # Opening a FIFO for writing without blocking fails when nothing reads it.
  def release_what_survived
    File.open(release, File::WRONLY | File::NONBLOCK) { |fifo| fifo.write("go\n") }
  rescue Errno::ENXIO
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
