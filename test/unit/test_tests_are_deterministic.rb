# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/call_scanner"

# Tests wait on nothing real: no sleeping, yielding for time or timeouts, and
# they reach state through public interfaces, never instance_variable_get/set.
class TestTestsAreDeterministic < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_no_test_or_feature_sleeps_times_out_or_reads_another_object_s_instance_variables
    assert_empty CallScanner.scan(ROOT, "{test,features}/**/*.rb", CallScanner::NONDETERMINISTIC)
  end
end
