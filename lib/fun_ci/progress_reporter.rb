# frozen_string_literal: true

module FunCi
  class ProgressReporter
    def initialize(stdout:)
      @stdout = stdout
    end

    def phase_one_result(results)
      markers = results.map { |stage, passed| "#{stage} #{result_marker(passed)}" }
      summary = results.values.all? ? "phase 1 passed" : "phase 1 failed"
      @stdout.puts "fun-ci: #{markers.join("  ")}  (#{summary})"
    end

    def fast_result(passed)
      @stdout.puts "fun-ci: fast #{result_marker(passed)}"
    end

    def slow_launched
      @stdout.puts "fun-ci: slow (running in background)"
    end

    private

    def result_marker(passed)
      passed ? "ok" : "FAIL"
    end
  end
end
