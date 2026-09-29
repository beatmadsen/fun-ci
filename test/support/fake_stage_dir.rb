# frozen_string_literal: true

require "fun_ci/pipeline/output_window"

# A stage's directory without a directory: it names a path no stage writes
# to, keeps its window in memory, and remembers being removed.
class FakeStageDir
  attr_reader :removed, :windows

  def initialize
    @windows = []
  end

  def output_file(_text) = "/fake/output.log"
  def scratch = "/fake"

  def window(sizes = FunCi::Pipeline::OutputWindow::REAL)
    FunCi::Pipeline::OutputWindow.in_memory(sizes).tap { |window| @windows << window }
  end

  def remove = @removed = true
end
