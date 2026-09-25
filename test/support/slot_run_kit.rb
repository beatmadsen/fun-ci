# frozen_string_literal: true

require "stringio"
require "fun_ci/pipeline/slot_run"
require "fun_ci/pipeline/slot"
require_relative "trigger_test_kit"

# Builds a SlotRun from in-memory stand-ins: a config that only names script
# paths, a scripted runner, a recorder that keeps calls, and a slot whose lock
# records being let go. No file system, no processes.
module SlotRunKit
  include TriggerTestKit

  Config = Struct.new(:root) do
    def script_path(stage) = "#{root}/.fun-ci/#{stage}.sh"
  end

  Lock = Struct.new(:closed?) do
    def close = self[:closed?] = true
  end

  def slot_with(lock) = FunCi::Pipeline::Slot.new("/slot-0", lock)

  # Seams default to a passing runner, a launcher that never starts the slow
  # suite, and a FakeRecorder.
  def slot_run(slot, io: quiet_io, **seams)
    defaults = { command_runner: scripted_runner, background_launcher: noop_launcher, recorder: FakeRecorder.new }
    FunCi::Pipeline::SlotRun.new(commit: FunCi::Pipeline::Commit.new(sha: "abc1234", branch: "main"), io: io,
                                 seams: FunCi::Pipeline::Seams.new(**defaults, **seams), slot: slot)
  end

  def config = Config.new("/slot-0")
end
