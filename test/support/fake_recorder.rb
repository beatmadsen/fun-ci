# frozen_string_literal: true

# Keeps the calls a pipeline makes of its recorder, in memory, without SQLite.
class FakeRecorder
  attr_reader :calls, :budgets

  # alongside: the stages it says shared the slot with any stage.
  def initialize(alongside: [])
    @calls = []
    @budgets = {}
    @alongside = alongside
    @next_job_id = 0
  end

  def create_run(commit_hash:, branch:, project_path: nil) = @calls << [:create_run, commit_hash, branch, project_path]

  def start_stage(stage, budget: nil) = new_stage(:start_stage, stage, budget)
  def schedule_stage(stage, budget: nil) = new_stage(:schedule_stage, stage, budget)
  def arrival_place = 0
  def started_in_turn?(job_id) = !(@calls << [:stage_started, stages[job_id - 1]]).nil?

  def end_stage(job_id, status) = @calls << [:end_stage, job_id, status]
  def keep_evidence(job_id, document) = @calls << [:keep_evidence, job_id, document]
  def keep_raw(job_id, text) = @calls << [:keep_raw, job_id, text]
  def trunk_checked(check) = @calls << [:trunk_checked, check]
  def trunk_fetched(fetched, tip) = @calls << [:trunk_fetched, fetched, tip]
  def trunk_fetch_process(pgid) = @calls << [:trunk_fetch_process, pgid]
  def trunk_check_started = @calls << [:trunk_check_started]
  def trunk_heads(**) = {}
  def trunk_fetches = FunCi::Persistence::TrunkRecording::NoFetches.new
  def alongside(_job_id) = @alongside
  def alongside_elsewhere(_job_id) = []
  def kept_evidence = @calls.select { |call| call.first == :keep_evidence }.map(&:last)
  def keep_exit(job_id, exit_status, signal) = @calls << [:keep_exit, job_id, exit_status, signal]
  def report_trouble_to(_out) = nil
  def tolerating = yield
  def stage_process(job_id, pid) = @calls << [:stage_process, job_id, pid]
  def slot_taken(lock_file) = @calls << [:slot_taken, lock_file]
  def foreground_done = @calls << [:foreground_done]
  def close = nil
  def db = nil
  def db_path = nil
  def pipeline_run_id = nil

  private

  # Each stage started or scheduled, in the order of their job ids.
  def stages = @calls.select { |call| %i[start_stage schedule_stage].include?(call.first) }.map(&:last)

  def new_stage(call, stage, budget)
    @calls << [call, stage]
    @budgets[stage] = budget
    @next_job_id += 1
  end
end
