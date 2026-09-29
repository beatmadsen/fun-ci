# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../script/stacks_doc/stack_table"

# The stacks page's table shows the command each script runs, not the
# comment above it saying which stage it runs beside.
class TestStacksDocTable < Minitest::Test
  def test_should_show_the_command_a_stage_script_runs
    assert_includes StacksDoc::StackTable.markdown, "| `mvn validate` | `mvn test-compile` | `mvn surefire:test` |"
  end
end
