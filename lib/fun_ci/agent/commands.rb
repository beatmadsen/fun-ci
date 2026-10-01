# frozen_string_literal: true

require_relative "../pipeline/trigger_params"
require_relative "context"
require_relative "git"
require_relative "system_clock"
require_relative "live_pipeline"
require_relative "status_command"
require_relative "runs_command"
require_relative "wait_command"
require_relative "events_command"
require_relative "why_command"
require_relative "jobs_command"
require_relative "cancel_command"
require_relative "../trunk/local"

module FunCi
  module Agent
    # The commands an agent runs in a project, each answered from the
    # database and the project's git.
    module Commands
      ALL = { "status" => StatusCommand, "runs" => RunsCommand, "wait" => WaitCommand,
              "events" => EventsCommand, "why" => WhyCommand, "jobs" => JobsCommand,
              "cancel" => CancelCommand }.freeze

      def self.run(name, args, context)
        ALL.fetch(name).new(context).run(args)
      end
    end
  end
end
