# frozen_string_literal: true

require_relative "../trunk/shown"

module FunCi
  module Agent
    # A run's trunk as the object of `status --json` (architecture.md, Checking against the trunk,
    # status --json): every field in every state, nil where it doesn't apply.
    # Fields once published keep their names.
    module TrunkJson
      def self.document(shown)
        { state: shown.state, **tip(shown.check&.tip), stale: shown.stale?, fetch: fetch(shown.fetch),
          fetch_error: shown.fetch_error, **merge(shown.check&.merge), moved_to: shown.moved_to }
      end

      NO_TIP = { ref: nil, sha: nil, as_of: nil }.freeze

      def self.tip(tip) = tip ? { ref: tip.ref, sha: tip.sha, as_of: tip.seen_at.utc.iso8601 } : NO_TIP

      def self.merge(merge)
        { ahead: merge&.ahead, behind: merge&.behind, files: merge&.files || [], reason: merge&.reason }
      end

      def self.fetch(last)
        return "none" unless last

        last.error ? "failed" : "ok"
      end
      private_class_method :tip, :merge, :fetch
    end
  end
end
