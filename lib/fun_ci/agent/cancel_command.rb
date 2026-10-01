# frozen_string_literal: true

require_relative "command_support"
require_relative "../jobs/folders"
require_relative "../persistence/active_jobs"

module FunCi
  module Agent
    # `fun-ci cancel --job NAME` (acceptance-tests.md, AT-13.26): stops a
    # daily or weekly job's running run, as `c` on its row in the console
    # does, and records it cancelled, so it is due again on the next commit.
    class CancelCommand
      include CommandSupport

      NAME = "cancel"

      def initialize(context)
        @context = context
      end

      def run(args)
        name = Options.parse(args, takes: %i[job]).job || raise(Options::Invalid, "name the job: --job NAME")
        raise Options::Invalid, no_job(name) unless names.include?(name)

        cancel(name, Persistence::ActiveJobs.running_of(@context.db, project, name))
      rescue Options::Invalid => e
        usage(e.message)
      end

      private

      def cancel(name, running)
        return say("job #{name} is not running, so there is nothing to cancel.") if running.empty?

        running.each { |id| @context.pipeline.cancel_job(@context.db, id) }
        say("cancelled job #{name}; it runs again on the next commit.")
      end

      def say(message)
        @context.io.stdout.puts "fun-ci: #{message}"
        0
      end

      def project = @context.git.toplevel
      def names = Jobs::Folders.new(project).jobs.map(&:name)

      def no_job(name)
        names.empty? ? JobWhy::NO_JOBS : "no job '#{name}' in this project: its jobs are #{names.join(", ")}"
      end
    end
  end
end
