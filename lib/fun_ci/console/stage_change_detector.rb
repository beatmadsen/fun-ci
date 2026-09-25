# frozen_string_literal: true

module FunCi
  module Console
    # The stages whose status differs between two polls of the runs, for the
    # runs both polls saw; none when there was no earlier poll.
    module StageChangeDetector
      Change = Data.define(:run_id, :stage, :from, :to)

      def self.detect(previous_runs, current_runs)
        current_by_id = current_runs.to_h { |run| [run[:id], run] }
        previous_runs.select { |run| current_by_id.key?(run[:id]) }
                     .flat_map { |run| compare_stages(run, current_by_id.fetch(run[:id])) }
      end

      def self.compare_stages(previous_run, current_run)
        before = statuses(previous_run[:stages])
        current_run[:stages].reject { |stage| before[stage[:stage]] == stage[:status] }
                            .map { |stage| change(current_run[:id], stage, before[stage[:stage]]) }
      end
      private_class_method :compare_stages

      def self.change(run_id, stage, from)
        Change.new(run_id: run_id, stage: stage[:stage], from: from, to: stage[:status])
      end
      private_class_method :change

      def self.statuses(stages) = (stages || []).to_h { |stage| [stage[:stage], stage[:status]] }
      private_class_method :statuses
    end
  end
end
