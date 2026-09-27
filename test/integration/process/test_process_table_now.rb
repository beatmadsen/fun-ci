# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/process_table"

# The processes this machine's own ps lists (why.md, "Overruns").
class TestProcessTableNow < Minitest::Test
  def test_should_list_this_process_with_its_group
    me = FunCi::Evidence::ProcessTable.now.find { |row| row.pid == Process.pid }

    assert_equal Process.getpgrp, me.pgid
  end
end
