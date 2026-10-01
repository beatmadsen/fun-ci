# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/process_runner"

# Where the files a command holds are open in it: from descriptor 10 up, clear
# of the gate's 9 and the standard three, whatever descriptor each has here,
# which may well be 9 in a process with few files open.
class TestProcessRunnerHeld < Minitest::Test
  FileStandIn = Data.define(:fileno)

  def test_should_open_the_first_held_file_at_descriptor_ten_in_the_command
    assert_equal [10], FunCi::Pipeline::ProcessRunner.held_descriptors([FileStandIn.new(fileno: 9)]).keys
  end

  def test_should_open_each_further_held_file_at_the_next_descriptor
    files = [FileStandIn.new(fileno: 9), FileStandIn.new(fileno: 4)]

    assert_equal [10, 11], FunCi::Pipeline::ProcessRunner.held_descriptors(files).keys
  end

  def test_should_open_each_held_file_itself
    file = FileStandIn.new(fileno: 9)

    assert_equal [file], FunCi::Pipeline::ProcessRunner.held_descriptors([file]).values
  end
end
