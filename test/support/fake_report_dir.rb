# frozen_string_literal: true

# A stage's report directory without a directory: it names a path no stage
# writes to, reports the failures it is given, and remembers being removed.
class FakeReportDir
  attr_reader :failures, :removed

  def initialize(failures = [])
    @failures = failures
  end

  def env = { "FUN_CI_REPORT" => "/fake/reports" }
  def remove = @removed = true
end
