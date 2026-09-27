# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/evidence_kit"
require "fun_ci/evidence/extractors/process_tree"
require "fun_ci/evidence/process_table"

# `process-tree`: the processes of a stage that ran over budget, before the
# kill (why.md, "Overruns").
class TestProcessTree < Minitest::Test
  include EvidenceKit

  ROW = FunCi::Evidence::ProcessTable::Row
  PROCESSES = [
    ROW.new(pid: 42, ppid: 1, pgid: 42, seconds: 10, command: "sh fast.sh"),
    ROW.new(pid: 43, ppid: 42, pgid: 42, seconds: 9, command: "gradle test"),
    ROW.new(pid: 44, ppid: 43, pgid: 42, seconds: 8, command: "java GradleWorkerMain"),
    ROW.new(pid: 50, ppid: 1, pgid: 50, seconds: 300, command: "vim notes.txt")
  ].freeze

  def test_should_say_the_deepest_process_of_the_group_was_running
    assert_equal [{ name: "running", value: "java GradleWorkerMain (8s)" }], tree.facts
  end

  def test_should_list_the_group_s_processes_as_a_tree
    assert_equal ["42 10s sh fast.sh", "  43 9s gradle test", "    44 8s java GradleWorkerMain"],
                 tree.excerpts.first[:lines]
  end

  def test_should_find_nothing_without_a_process_group
    assert_empty tree(pgid: nil).facts
  end

  private

  def tree(pgid: 42)
    context = context(pgid: pgid, processes: -> { PROCESSES })
    FunCi::Evidence::Extractors::ProcessTree.new({}).extract(context)
  end
end
