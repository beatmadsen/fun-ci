# frozen_string_literal: true

require "fileutils"
require_relative "board_data"
require_relative "console_log"
require_relative "console_loop"
require_relative "console_session"
require_relative "renderer_process"

module FunCi
  module Console
    # `fun-ci console`: starts the renderer, which draws on the terminal, and
    # talks to it about the runs in `db` until the user quits. The renderer's
    # stderr and what it gets wrong go to the project's .fun-ci/console.log.
    module Launcher
      PATIENCE = 5

      # The exit status: 0 once the user has quit, 1 if the renderer stopped.
      def self.run(renderer:, db:, project_dir:, stderr:)
        log = ConsoleLog.new(project_dir: project_dir, clock: -> { Time.now })
        FileUtils.mkdir_p(File.dirname(log.path))
        process = RendererProcess.start([renderer], err: [log.path, "a"])
        outcome = converse(process, BoardData.new(db), log)
        report(outcome, process.finish(patience: PATIENCE), stderr)
      end

      def self.converse(process, board_data, log)
        session = ConsoleSession.build(board_data: board_data, port: process, clock: -> { Time.now }, log: log)
        ConsoleLoop.new(session: session, renderer: process).run
      rescue Errno::EPIPE
        :ended
      end
      private_class_method :converse

      def self.report(outcome, status, stderr)
        return 0 if outcome == :quit && status.success?

        stderr.puts "fun-ci console: the renderer stopped (#{status}); see .fun-ci/console.log"
        1
      end
      private_class_method :report
    end
  end
end
