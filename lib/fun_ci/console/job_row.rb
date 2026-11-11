# frozen_string_literal: true

module FunCi
  module Console
    # A job as the job section holds it: where it stands (Jobs::Standing),
    # and how the user hid it, `snoozed` or `ignored` (Persistence::JobVisibility);
    # nil while it is in view.
    JobRow = Data.define(:standing, :hidden)

    class JobRow
      def name = standing.name
      def project = standing.project
      def state = standing.state
      def run = standing.run
    end
  end
end
