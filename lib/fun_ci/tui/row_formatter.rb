# frozen_string_literal: true

require_relative "ansi"
require_relative "duration_formatter"
require_relative "relative_time"

module FunCi
  module Tui
    module RowFormatter
      STAGE_NAMES = { "lint" => "Lint", "build" => "Build", "fast" => "Fast", "slow" => "Slow" }.freeze
      STATUS_LABELS = {
        "completed" => "PASSED", "failed" => "FAILED", "timed_out" => "TIMED OUT",
        "running" => "RUNNING", "scheduled" => "Scheduled...", "cancelled" => "CANCELLED"
      }.freeze
      PROJECT_COLORS = %w[31 32 33 34 35 36 91 92 93 94].freeze

      def self.format(run, now: Time.now, spinner_frame: nil, elapsed_seconds: nil)
        commit = run[:commit_hash][0, 7]
        branch = run[:branch]
        status = run[:status]
        project = format_project(run[:project_path])

        case status
        when "scheduled"
          format_scheduled(commit, branch, project, run[:updated_at], now)
        when "cancelled"
          format_cancelled(commit, branch, project, run[:stages], run[:updated_at], now)
        else
          stages_text = format_stages(run[:stages], status, spinner_frame, elapsed_seconds)
          status_text = format_status(status)
          time_text = Ansi.dim(RelativeTime.format(run[:updated_at], now: now))
          "  #{commit}  #{branch}#{project}  #{stages_text}  #{status_text}  #{time_text}"
        end
      end

      def self.format_project(project_path)
        return "" unless project_path
        name = File.basename(project_path)
        code = PROJECT_COLORS[name.hash.abs % PROJECT_COLORS.size]
        "  \e[#{code}m#{name}#{Ansi::RESET}"
      end
      private_class_method :format_project

      def self.format_scheduled(commit, branch, project, updated_at, now)
        time_text = RelativeTime.format(updated_at, now: now)
        Ansi.dim("  #{commit}  #{branch}#{project}  Scheduled...  #{time_text}")
      end
      private_class_method :format_scheduled

      def self.format_cancelled(commit, branch, project, stages, updated_at, now)
        stages_text = stages.map { |s| format_cancelled_stage(s) }.join("  ")
        time_text = RelativeTime.format(updated_at, now: now)
        Ansi.dim("  #{commit}  #{branch}#{project}  #{stages_text}  CANCELLED  #{time_text}")
      end
      private_class_method :format_cancelled

      def self.format_cancelled_stage(stage)
        name = STAGE_NAMES[stage[:stage]]
        if stage[:duration]
          "#{name} #{DurationFormatter.format(stage[:duration])}"
        else
          "#{name} --"
        end
      end
      private_class_method :format_cancelled_stage

      def self.format_stages(stages, run_status, spinner_frame, elapsed_seconds)
        stages.map { |s| format_stage(s, spinner_frame, elapsed_seconds) }.join("  ")
      end
      private_class_method :format_stages

      def self.format_stage(stage, spinner_frame, elapsed_seconds)
        name = STAGE_NAMES[stage[:stage]]

        case stage[:status]
        when "completed"
          time = DurationFormatter.format(stage[:duration])
          Ansi.green("#{name} #{time}")
        when "failed"
          time = DurationFormatter.format(stage[:duration])
          Ansi.bold_red("#{name} FAIL #{time}")
        when "timed_out"
          time = DurationFormatter.format(stage[:duration])
          Ansi.bold_yellow("#{name} TIMEOUT #{time}")
        when "running"
          frame = spinner_frame || "\u2800"
          time = elapsed_seconds ? "#{elapsed_seconds.to_i}s" : "--"
          Ansi.cyan("#{name} #{frame} #{time}")
        else
          Ansi.dim("#{name} --")
        end
      end
      private_class_method :format_stage

      def self.format_status(status)
        label = STATUS_LABELS[status]
        case status
        when "completed" then Ansi.bold_green(label)
        when "failed"    then Ansi.bold_red(label)
        when "timed_out" then Ansi.bold_yellow(label)
        when "running"   then Ansi.bold_cyan(label)
        else Ansi.dim(label)
        end
      end
      private_class_method :format_status
    end
  end
end
