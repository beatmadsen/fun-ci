# frozen_string_literal: true

require_relative "../trunk/shown"
require_relative "age"
require_relative "next_step"

module FunCi
  module Agent
    # How a run's commit stands against the trunk, as `status` and `wait`
    # print it (design.md, The trunk).
    module TrunkText
      # next_step: whether to say how to integrate a conflict; not while a needed stage has failed.
      def self.lines(shown, branch:, next_step:)
        return ["  trunk  checking"] unless shown.check

        files = shown.check.merge.files
        ["  trunk  #{shown.state.tr("_", " ").ljust(12)} #{detail(shown)}".rstrip, *files.map { |file| "    #{file}" },
         *moved(shown),
         *(next_step && shown.state == "conflicts" ? [NextStep.line(shown.check.tip, files, branch: branch)] : [])]
      end

      def self.moved(shown)
        return [] unless shown.moved_to

        ["    #{shown.check.tip.ref} has moved to #{shown.moved_to[0, 7]} since; fun-ci status --trunk checks again"]
      end

      def self.detail(shown)
        merge = shown.check.merge
        return merge.reason if shown.state == "unknown"
        return "" if shown.state == "in_trunk"

        seen = seen(shown)
        shown.state == "up_to_date" ? seen : "#{seen}, #{merge.ahead} ahead, #{merge.behind} behind"
      end

      def self.seen(shown)
        tip = shown.check.tip
        "#{tip.ref} #{tip.sha[0, 7]}, fetched #{Age.words(shown.age)}#{stale(shown)}"
      end

      def self.stale(shown)
        return "" unless shown.stale?

        shown.fetch_error ? ", STALE (fetch failed: #{shown.fetch_error})" : ", STALE"
      end
      private_class_method :moved, :detail, :seen, :stale
    end
  end
end
