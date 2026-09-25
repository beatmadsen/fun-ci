# frozen_string_literal: true

require_relative "../test_helper"
require "yaml"

# AT-0.1: offences are fixed, not excluded. The todo may only hold code that
# §3.6 and §5 delete.
class TestRubocopTodo < Minitest::Test
  TODO = File.expand_path("../../.rubocop_todo.yml", __dir__)
  DELETED_IN_V2 = %r{\Alib/fun_ci/(tui|animations)/}

  def test_the_todo_names_only_code_v2_deletes
    stray = todo.values.flat_map { |cop| cop.fetch("Exclude", []) }.uniq.grep_v(DELETED_IN_V2)

    assert_empty stray
  end

  def test_the_todo_only_excludes_files_and_never_loosens_a_setting
    loosened = todo.reject { |_cop, settings| settings.keys == ["Exclude"] }.keys

    assert_empty loosened
  end

  private

  def todo
    YAML.safe_load_file(TODO)
  end
end
