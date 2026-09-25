# frozen_string_literal: true

require "json"
require_relative "console_state"
require_relative "view"
require_relative "key_handler"

module FunCi
  module Console
    # The console's half of the renderer conversation (renderer-protocol.md):
    # it reads the renderer's lines and writes protocol messages to the port.
    # Ruby decides what is true here; drawing it is the renderer's job.
    class ConsoleSession
      VERSION = 1
      HANDLERS = { "ready" => :ready, "resize" => :resize, "key" => :key, "error" => :renderer_error }.freeze

      # `log` takes what the renderer got wrong (ConsoleLog).
      def self.build(board_data:, port:, clock:, log:)
        view = View.new(key_handler: KeyHandler.new(board_data: board_data))
        new(state: ConsoleState.new(board_data: board_data, view: view, clock: clock), port: port, log: log)
      end

      def initialize(state:, port:, log:)
        @state = state
        @port = port
        @log = log
        @phase = :starting
      end

      def start = @port.write(t: "hello", v: VERSION)

      # A line the renderer wrote. One it got wrong is logged, never raised.
      def receive(line)
        message = JSON.parse(line)
        message.is_a?(Hash) ? handle(message) : @log.write("the renderer sent a line that is not a message: #{line}")
      rescue JSON::ParserError
        @log.write("the renderer sent a line that is not JSON: #{line.inspect}")
      end

      # Sends what the runs look like now, as each poll does; nothing before
      # the renderer is ready, since its size decides the page.
      def refresh = @phase == :running && send_updates

      def finished? = @phase == :finished

      private

      def handle(message)
        handler = HANDLERS[message["t"]]
        return @log.write("the renderer sent a message of unknown type #{message["t"].inspect}") unless handler

        send(handler, message)
      end

      def ready(message)
        @phase = :running
        resize(message)
      end

      def resize(message)
        @state.resize(message["rows"])
        send_updates
      end

      def key(message)
        return send_updates unless @state.press(message["key"]) == :quit

        @phase = :finished
        @port.write(t: "quit")
      end

      def renderer_error(message)
        @log.write("the renderer reported a #{message["code"]} error: #{message["detail"]}")
      end

      def send_updates = @state.updates.each { |update| @port.write(update) }
    end
  end
end
