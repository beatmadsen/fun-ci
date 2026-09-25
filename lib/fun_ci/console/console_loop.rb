# frozen_string_literal: true

require_relative "renderer_process"

module FunCi
  module Console
    # The console's conversation with its renderer: each line the renderer
    # writes goes to the session, and whenever the renderer has been quiet for
    # POLL_SECONDS the session polls the runs, so what the database holds
    # reaches the screen without waiting for a key.
    class ConsoleLoop
      POLL_SECONDS = 1

      def initialize(session:, renderer:)
        @session = session
        @renderer = renderer
      end

      # :quit once the session has quit, :ended if the renderer went away first.
      def run
        @session.start
        loop do
          return :quit if @session.finished?
          return :ended unless step
        end
      end

      private

      # False once the renderer has closed its output.
      def step
        line = @renderer.next_line(patience: POLL_SECONDS)
        @session.receive(line) if line
        !line.nil?
      rescue RendererProcess::Silent
        @session.refresh
        true
      end
    end
  end
end
