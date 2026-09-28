# frozen_string_literal: true

require "fileutils"
require_relative "board_data"
require_relative "console_log"
require_relative "console_loop"
require_relative "console_session"
require_relative "renderer_process"
require_relative "stop_report"

module FunCi
  module Console
    # `fun-ci console`: starts the renderer, which draws on the terminal, and
    # talks to it about the runs in `db` until the user quits. The renderer's
    # stderr, what it gets wrong, and when and why the console started and
    # stopped go to the project's .fun-ci/console.log.
    module Launcher
      PATIENCE = 5

      # The exit status: 0 once the user has quit, 1 if the renderer stopped
      # or the console failed.
      def self.run(renderer:, db:, project_dir:, stderr:)
        log = ConsoleLog.new(project_dir: project_dir, clock: -> { Time.now })
        FileUtils.mkdir_p(File.dirname(log.path))
        process = RendererProcess.start([renderer], err: [log.path, "a"])
        log.write("console started; the renderer is pid #{process.pid}")
        outcome = converse(process, BoardData.new(db), log)
        StopReport.new(outcome, process.finish(patience: PATIENCE)).tell(log, stderr)
      end

      # :quit, :ended, or the error that ended the conversation.
      def self.converse(process, board_data, log)
        session = ConsoleSession.build(board_data: board_data, port: process, clock: -> { Time.now }, log: log)
        ConsoleLoop.new(session: session, renderer: process).run
      rescue Errno::EPIPE
        :ended
      rescue StandardError => e
        e
      end
      private_class_method :converse
    end
  end
end
