# frozen_string_literal: true

require_relative "../pipeline/trigger_params"
require_relative "context"
require_relative "status_command"

module FunCi
  module Agent
    # The commands an agent runs in a project, each answered from the
    # database and the project's git.
    module Commands
      ALL = { "status" => StatusCommand }.freeze

      def self.run(name, args, context)
        ALL.fetch(name).new(context).run(args)
      end
    end
  end
end
