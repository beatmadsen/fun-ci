# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/process_tree"
require "fun_ci/evidence/process_table"

# What else to kill with a stage's process group: the processes descended
# from it that left the group, as Node's detached children (Playwright's web
# server) do, found by parent id before the kill orphans them.
class TestStageProcessTree < Minitest::Test
  STAGE = 300

  def test_should_reach_a_descendant_that_leads_a_group_of_its_own_through_its_group
    rows = [row(300, 1, STAGE), row(310, 300, STAGE), row(320, 310, 320)]

    assert_equal [-320], escaped(rows)
  end

  def test_should_reach_a_descendant_that_joined_another_group_alone
    rows = [row(300, 1, STAGE), row(320, 300, 999), row(999, 1, 999)]

    assert_equal [320], escaped(rows)
  end

  def test_should_reach_the_children_of_a_process_that_left_the_group
    rows = [row(300, 1, STAGE), row(320, 300, 320), row(330, 320, 320)]

    assert_equal [-320], escaped(rows)
  end

  def test_should_leave_out_the_group_s_own_members
    rows = [row(300, 1, STAGE), row(310, 300, STAGE)]

    assert_empty escaped(rows)
  end

  def test_should_leave_out_processes_the_group_did_not_start
    rows = [row(300, 1, STAGE), row(400, 1, 400), row(410, 400, 400)]

    assert_empty escaped(rows)
  end

  def test_should_end_on_a_table_whose_parent_ids_form_a_cycle
    rows = [row(300, 1, STAGE), row(320, 330, 320), row(330, 320, 320)]

    assert_empty escaped(rows)
  end

  private

  def escaped(rows) = FunCi::Pipeline::ProcessTree.escaped([STAGE], rows)

  def row(pid, ppid, pgid)
    FunCi::Evidence::ProcessTable::Row.new(pid: pid, ppid: ppid, pgid: pgid, seconds: 1, command: "x")
  end
end
