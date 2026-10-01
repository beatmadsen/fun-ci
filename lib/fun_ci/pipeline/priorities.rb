# frozen_string_literal: true

module FunCi
  module Pipeline
    # What a daily or weekly job and the slow suite are started under, so
    # they give way to the stages a push waits for: each a prefix of the
    # command a stage's shell execs, or "" for none. On macOS nice barely
    # moves the scheduler, and a QoS clamp of utility lets a job have every
    # idle core yet yield to the stages; the slow suite is left unclamped
    # there, since clamped beside clamped jobs it crawls. Elsewhere nice does it.
    Priorities = Data.define(:job, :slow)

    class Priorities
      MACOS = new(job: "taskpolicy -c utility ", slow: "")
      OTHER = new(job: "nice -n 19 ", slow: "nice -n 10 ")

      # platform: as RUBY_PLATFORM names it.
      def self.for(platform) = platform.include?("darwin") ? MACOS : OTHER
    end
  end
end
