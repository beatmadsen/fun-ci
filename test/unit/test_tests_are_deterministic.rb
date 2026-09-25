# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/call_scanner"

# Tests wait on nothing real: no sleeping, yielding for time or timeouts, and
# they reach state through public interfaces, never instance_variable_get/set.
class TestTestsAreDeterministic < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_no_test_or_feature_sleeps_times_out_or_reads_another_object_s_instance_variables
    offences = Dir.glob("{test,features}/**/*.rb", base: ROOT).flat_map do |path|
      CallScanner.new(File.read(File.join(ROOT, path)), path, CallScanner::NONDETERMINISTIC).offences
    end

    assert_empty offences
  end
end
