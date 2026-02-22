# frozen_string_literal: true

module FunCi
  module StageChangeDetector
    Change = Data.define(:run_id, :stage, :from, :to)

    def self.detect(previous_runs, current_runs)
      return [] if previous_runs.empty?

      current_by_id = index_by_id(current_runs)
      changes = []

      previous_runs.each do |prev_run|
        cur_run = current_by_id[prev_run[:id]]
        next unless cur_run

        changes.concat(compare_stages(prev_run, cur_run))
      end

      changes
    end

    def self.index_by_id(runs)
      runs.each_with_object({}) { |r, h| h[r[:id]] = r }
    end
    private_class_method :index_by_id

    def self.compare_stages(prev_run, cur_run)
      prev_stages = index_stages(prev_run[:stages])
      changes = []

      cur_run[:stages].each do |cur_stage|
        prev_stage = prev_stages[cur_stage[:stage]]
        prev_status = prev_stage ? prev_stage[:status] : nil
        next if prev_status == cur_stage[:status]

        changes << Change.new(
          run_id: cur_run[:id],
          stage: cur_stage[:stage],
          from: prev_status,
          to: cur_stage[:status]
        )
      end

      changes
    end
    private_class_method :compare_stages

    def self.index_stages(stages)
      return {} unless stages

      stages.each_with_object({}) { |s, h| h[s[:stage]] = s }
    end
    private_class_method :index_stages
  end
end
