# frozen_string_literal: true

require_relative "options"
require_relative "reports"
require_relative "exit_code"

module FunCi
  module Agent
    # What the agent commands share: the commit a revision names, the reports
    # of its runs, and refusing arguments they can't use. Expects @context and
    # a NAME constant.
    module CommandSupport
      private

      def resolve(rev)
        @context.git.resolve(rev) || raise(Options::Invalid, "git can't find the commit '#{rev}'")
      end

      def reports = Reports.new(@context.db, @context.git)

      def usage(message)
        @context.io.stderr.puts "fun-ci #{self.class::NAME}: #{message}"
        ExitCode::USAGE
      end
    end
  end
end
