# frozen_string_literal: true

require "fun_ci/pipeline/output_window"

# A stage's directory without a directory: it names a path no stage writes
# to, reports the failures it is given, keeps its window in memory, and
# remembers being removed.
class FakeStageDir
  attr_reader :failures, :removed, :windows

  def initialize(failures = [])
    @failures = failures
    @windows = []
  end

  def env = { "FUN_CI_REPORT" => "/fake/reports" }

  def window(sizes = FunCi::Pipeline::OutputWindow::REAL)
    FunCi::Pipeline::OutputWindow.in_memory(sizes).tap { |window| @windows << window }
  end

  def remove = @removed = true
end
