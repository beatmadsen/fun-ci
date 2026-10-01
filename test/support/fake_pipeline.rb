# frozen_string_literal: true

# The pipeline an agent command can start, check on or cancel a job of, as
# calls to record. A project not `set_up` starts no run.
class FakePipeline
  attr_reader :started, :watched, :cancelled_jobs
  attr_accessor :set_up

  def initialize
    @started = []
    @watched = 0
    @set_up = true
    @cancelled_jobs = []
  end

  def start(sha, branch)
    @started << [sha, branch] if set_up
    set_up
  end

  def watch(_db) = @watched += 1
  def cancel_job(_db, id) = @cancelled_jobs << id
end
