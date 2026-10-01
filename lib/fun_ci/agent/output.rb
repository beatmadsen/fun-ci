# frozen_string_literal: true

require "json"
require_relative "status_text"
require_relative "why_text"
require_relative "why_json"
require_relative "status_json"
require_relative "runs_text"
require_relative "exit_code"
require_relative "evidence_text"
require_relative "trunk_why_json"
require_relative "job_json"
require_relative "job_report"

module FunCi
  module Agent
    # Prints what an agent command found, as text or, with --json, as JSON.
    class Output
      NO_CONFLICT = "No conflict with the trunk to explain."
      NO_STAGE = "No stage it needs failed or ran over budget; name one to see it: fun-ci why REV STAGE"

      # trunk: whether the agent asked about the trunk (--trunk).
      def initialize(stdout, json:, trunk: false)
        @stdout = stdout
        @json = json
        @trunk = trunk
      end

      # jobs: the commit's CommitJobs, when asked about.
      def report(report, jobs: nil)
        return print_json(with_jobs(StatusJson.document(report), jobs)) if @json

        print_lines(StatusText.lines(report, trunk: @trunk, jobs: jobs || CommitJobs::NONE))
      end

      # Everything kept about the stage named, or says no stage decided the verdict.
      def why(report, stage_name)
        stage = report.stages.find { |candidate| candidate.name == stage_name }
        return print_json(WhyJson.document(report, stage)) if @json
        return print_lines([StatusText.header(report), NO_STAGE]) unless stage

        print_lines(WhyText.lines(report, stage))
      end

      # The run's conflict with the trunk; document nil when there is none to explain.
      def why_trunk(report, document)
        return print_json(TrunkWhyJson.document(report, document)) if @json

        print_lines([StatusText.header(report), *StatusText.trunk(report, true),
                     *(document ? EvidenceText.lines(document) : ["", NO_CONFLICT])])
      end

      # Says the commit has no run, and answers the exit code for that.
      def unknown(sha)
        @json ? print_json(StatusJson.unknown(sha)) : print_lines(["fun-ci: no run for #{sha[0, 7]} in this project."])
        ExitCode::FOR.fetch(:unknown)
      end

      # Says the commit has no run and none can start, which leaves it unknown.
      def not_set_up(sha)
        if @json
          print_json(StatusJson.unknown(sha))
        else
          print_lines(["fun-ci: no run for #{sha[0, 7]}, and this project isn't set up to start one."])
        end
        ExitCode::FOR.fetch(:unknown)
      end

      # Says the commit has no run yet, which leaves it undecided.
      def no_run_yet(sha)
        if @json
          print_json(StatusJson.unknown(sha).merge(verdict: "undecided"))
        else
          print_lines(["fun-ci: no run for #{sha[0, 7]} yet."])
        end
        ExitCode::FOR.fetch(:undecided)
      end

      # Says the wait moves on to the commit that superseded `sha`; JSON has only the answer.
      def following(sha, report)
        return if @json

        @stdout.puts "fun-ci: #{sha[0, 7]} was superseded; following #{report.branch} to #{report.superseded_by[0, 7]}."
      end

      # entries: [[report, age in words], ...], newest first.
      def runs(entries)
        return print_json(entries.map { |report, _| StatusJson.document(report) }) if @json

        print_lines(RunsText.lines(entries))
      end

      private

      def with_jobs(document, jobs)
        return document unless jobs

        document.merge(jobs: jobs.on_commit.map { |job| JobJson.document(job) },
                       failing_jobs: jobs.failing.map { |job| JobJson.document(job) })
      end

      def print_json(document) = @stdout.puts(JSON.generate(document))
      def print_lines(lines) = lines.each { |line| @stdout.puts line }
    end
  end
end
