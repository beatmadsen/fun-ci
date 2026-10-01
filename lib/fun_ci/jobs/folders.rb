# frozen_string_literal: true

require_relative "job"

module FunCi
  module Jobs
    # The jobs a project keeps in .fun-ci/daily/ and .fun-ci/weekly/: each
    # executable `<name>.sh`. A script that can't run, or a name in both
    # folders, is no job; #errors says why, for `fun-ci check`.
    class Folders
      CADENCES = Job::PERIODS.keys

      def initialize(project_root)
        @fun_ci_dir = File.join(project_root, ".fun-ci")
      end

      # By name.
      def jobs = scripts.select { |job| runnable?(job) && !twice.include?(job.name) }.sort_by(&:name)

      def errors
        not_executable = scripts.reject { |job| File.executable?(job.script) }
        not_executable.map { |job| ".fun-ci/#{job.cadence}/#{job.name}.sh is not executable" } +
          twice.map { |name| "the job #{name} is in both .fun-ci/daily/ and .fun-ci/weekly/: rename one" }
      end

      private

      def runnable?(job) = File.executable?(job.script)

      def twice = scripts.group_by(&:name).select { |_, jobs| jobs.size > 1 }.keys.sort

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
