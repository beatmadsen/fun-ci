# frozen_string_literal: true

# The pipeline an agent command can start or check on, as calls to record.
class FakePipeline
  attr_reader :started, :watched

  def initialize
    @started = []
    @watched = 0
  end

  def start(sha, branch) = @started << [sha, branch]
  def watch(_db) = @watched += 1
end
