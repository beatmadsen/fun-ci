# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../contract/capture/protocol_run"

class TestProtocolRun < Minitest::Test
  RUN = {
    "id" => 7, "sha" => "a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4c6d8e0f", "branch" => "main",
    "project" => "/src/fun-ci", "status" => "passed", "updated_at" => 1_790_000_000,
    "stages" => [{ "stage" => "lint", "status" => "timeout", "duration_ms" => 1500 }]
  }.freeze

  def test_run_statuses_become_the_1x_names
    translated = %w[pending passed timeout running].map { |s| to_tui("status" => s)[:status] }

    assert_equal %w[scheduled completed timed_out running], translated
  end

  def test_stage_statuses_become_the_1x_names
    assert_equal "timed_out", to_tui[:stages].first[:status]
  end

  def test_epoch_seconds_become_utc_iso8601
    assert_equal "2026-09-21T14:13:20Z", to_tui[:updated_at]
  end

  def test_milliseconds_become_seconds
    assert_in_delta 1.5, to_tui[:stages].first[:duration]
  end

  def test_a_stage_without_duration_or_start_keeps_them_nil
    stage = to_tui("stages" => [{ "stage" => "slow", "status" => "pending" }])[:stages].first

    assert_equal [nil, nil], stage.values_at(:duration, :started_at)
  end

  def test_identity_fields_carry_over
    assert_equal [7, RUN["sha"], "main", "/src/fun-ci"],
                 to_tui.values_at(:id, :commit_hash, :branch, :project_path)
  end

  private

  def to_tui(overrides = {})
    FunCi::Contract::ProtocolRun.to_tui(RUN.merge(overrides))
  end
end
