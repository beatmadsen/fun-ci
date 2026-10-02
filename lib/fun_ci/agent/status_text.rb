# frozen_string_literal: true

require_relative "run_report"
require_relative "verdict"
require_relative "digest"
require_relative "trunk_text"
require_relative "job_report"
require_relative "starts_in"

module FunCi
  module Agent
    # A run report as text: the commit, a line per stage with what went wrong
    # in capitals, then the evidence of each needed stage that failed.
    module StatusText
      WORDS = { "failed" => "FAILED", "over_budget" => "OVER BUDGET", "lost" => "LOST" }.freeze

      # trunk: whether the agent asked about the trunk, which says so while its
      # check is going; jobs: the commit's CommitJobs, which change nothing
      # about the verdict.
      def self.lines(report, trunk: false, jobs: CommitJobs::NONE)
        needed = Verdict::LEVELS.fetch(report.need)
        [header(report), *report.stages.map { |stage| stage_line(stage, needed) }, *Digest.lines(report.stages, needed),
         *job_lines(jobs), *trunk(report, trunk), *footer(report)]
      end

      def self.job_lines(jobs)
        jobs.on_commit.map { |job| job_line(job) } + jobs.failing.map { |job| job_line(job, " on #{job.sha[0, 7]}") }
      end

      # `  soak (weekly job) FAILED  fun-ci why --job soak`; `where` names the
      # commit it tested when that is another.
      def self.job_line(job, where = "")
        said = "  #{job.name} (#{job.cadence} job) #{WORDS.fetch(job.state, job.state)}#{starts(job)}#{where}"
        job.needs_you? ? "#{said}  fun-ci why --job #{job.name}" : said
      end

      # `, starts in 8m` for a job waiting its turn.
      def self.starts(job) = job.starts_in ? ", #{StartsIn.words(job.starts_in)}" : ""

      # The trunk lines; nothing while the check is going, unless asked about
      # (right after a commit it would say nothing useful).
      def self.trunk(report, asked)
        return [] if report.trunk.nil? || (report.trunk.state == "checking" && !asked)

        TrunkText.lines(report.trunk, branch: report.branch, next_step: report.deciding.nil?)
      end

      def self.header(report) = %(fun-ci: #{report.sha[0, 7]} "#{report.subject}" on #{report.branch})

      def self.stage_line(stage, needed)
        seconds = stage.seconds ? format("%6.1fs", stage.seconds) : " " * 7
        note = needed.include?(stage.name) ? "" : " (not needed)"
        "  #{stage.name.ljust(6)} #{WORDS.fetch(stage.state, stage.state).ljust(12)}#{seconds}#{note}".rstrip
      end

      def self.footer(report)
        return ["fun-ci why #{report.sha[0, 7]} #{report.deciding}"] if report.deciding
        return ["fun-ci why #{report.sha[0, 7]} trunk"] if report.trunk&.state == "conflicts"
        return [] unless report.verdict == :superseded && report.superseded_by

        ["Superseded by #{report.superseded_by[0, 7]}."]
      end
      private_class_method :stage_line, :footer, :job_lines, :job_line, :starts
    end
  end
end
