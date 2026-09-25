# frozen_string_literal: true

require_relative "../test_helper"
require "yaml"

# AT-0.1: offences are fixed, not excluded. The todo that held the Ruby
# renderer's code went with it (AT-5.3b); nothing may bring one back.
class TestRubocopTodo < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_should_have_no_todo_file
    refute_path_exists File.join(ROOT, ".rubocop_todo.yml")
  end

  def test_should_inherit_no_exclusions_from_another_file
    assert_nil YAML.safe_load_file(File.join(ROOT, ".rubocop.yml"))["inherit_from"]
  end
end
