# frozen_string_literal: true

require_relative "../test_helper"
require "yaml"

# AT-0.1: offences are fixed, not excluded. The todo may only hold code that
# §3.6 and §5 delete, plus the files AT-0.2 redesigns.
class TestRubocopTodo < Minitest::Test
  TODO = File.expand_path("../../.rubocop_todo.yml", __dir__)
  DELETED_IN_V2 = %r{\Alib/fun_ci/(tui|animations)/}
  AWAITING_AT_0_2 = %w[
    lib/fun_ci/pipeline/trigger.rb
    lib/fun_ci/pipeline/stage_runner.rb
    test/acceptance/test_trigger_fork_integration.rb
    test/acceptance/test_tui_project_path.rb
    test/acceptance/trigger_cli_client.rb
    test/unit/test_stage_runner.rb
    test/unit/test_trigger.rb
    test/unit/test_trigger_parallel.rb
    test/unit/test_trigger_parallel_phase_two.rb
    test/unit/test_trigger_progress.rb
    test/unit/test_trigger_project_path.rb
  ].freeze

  def test_the_todo_names_only_code_v2_deletes_or_at_0_2_redesigns
    stray = todo.values.flat_map { |cop| cop.fetch("Exclude", []) }.uniq
                .reject { |path| path.match?(DELETED_IN_V2) || AWAITING_AT_0_2.include?(path) }

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
