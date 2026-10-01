# frozen_string_literal: true

require_relative "job"

module FunCi
  module Jobs
    # The jobs a project keeps in .fun-ci/daily/ and .fun-ci/weekly/: each
    # executable `<name>.sh`. A script that can't run, or a name in both
    # folders, is no job; #errors says why, for `fun-ci check`.
    class Folders
      CADENCES = Job::PERIODS.keys
      # A name a command line keeps whole, since agents paste it: fun-ci why --job NAME.
      NAME = /\A[A-Za-z0-9._-]+\z/

      def initialize(project_root)
        @fun_ci_dir = File.join(project_root, ".fun-ci")
      end

      # By name.
      def jobs
        all = scripts
        twice = twice(all)
        all.select { |job| runnable?(job) && NAME.match?(job.name) && !twice.include?(job.name) }.sort_by(&:name)
      end

      def errors
        all = scripts
        all.reject { |job| runnable?(job) }.map { |job| "#{path(job)} is not executable" } +
          all.reject { |job| NAME.match?(job.name) }.map { |job| misnamed(job) } +
          twice(all).map { |name| "the job #{name} is in both .fun-ci/daily/ and .fun-ci/weekly/: rename one" }
      end

      private

      def runnable?(job) = File.executable?(job.script)
      def path(job) = ".fun-ci/#{job.cadence}/#{job.name}.sh"
      def misnamed(job) = "the job '#{job.name}' needs a name of letters, digits, '.', '_' and '-': rename #{path(job)}"

      def twice(all) = all.group_by(&:name).select { |_, jobs| jobs.size > 1 }.keys.sort

      def scripts
        CADENCES.flat_map do |cadence|
          Dir.glob("*.sh", base: File.join(@fun_ci_dir, cadence)).map do |file|
            Job.new(name: File.basename(file, ".sh"), cadence: cadence, script: File.join(@fun_ci_dir, cadence, file))
          end
        end
      end
    end
  end
end
