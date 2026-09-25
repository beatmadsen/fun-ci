# frozen_string_literal: true

require "io/console"
require "json"
require "pty"
require "fun_ci/console/console_session"
require "fun_ci/console/renderer_process"
require_relative "../../test/support/console_fakes"
require_relative "../../test/support/fixture_replay"

# Replays a contract fixture against the real renderer binary: a real
# ConsoleSession talks to it through RendererProcess, the binary draws on a
# pseudo-terminal sized as the fixture's `ready` says, and each `key` the
# fixture has the renderer send is typed on that terminal. The conversation
# is every line either side sent, spelt as a fixture spells it.
class BinaryConversation
  PATIENCE = 10
  TYPED = { "up" => "\e[A", "down" => "\e[B", "enter" => "\r", "esc" => "\e", "ctrl_c" => "\x03" }.freeze

  # Writes to the renderer, keeping each message as a `ruby` line.
  Recording = Struct.new(:renderer, :conversation) do
    def write(message)
      conversation << { "ruby" => JSON.parse(JSON.generate(message)) }
      renderer.write(message)
    end
  end

  def initialize(binary, lines)
    @binary = binary
    @lines = lines
    @conversation = []
    @store = FixtureReplay::Store.new
  end

  # The conversation, and how the binary exited.
  def play
    PTY.open do |terminal, device|
      terminal.winsize = size
      Thread.new { drain(terminal) }
      talk(terminal, device.path)
    end
  end

  private

  def talk(terminal, device)
    renderer = FunCi::Console::RendererProcess.start([@binary, "--tty", device])
    session = session_with(renderer)
    @lines.each { |line| step(session, renderer, terminal, line) }
    [@conversation, renderer.finish(patience: PATIENCE)]
  rescue StandardError
    renderer&.finish(patience: 1)
    raise
  end

  def session_with(renderer)
    FunCi::Console::ConsoleSession.build(board_data: @store, port: Recording.new(renderer, @conversation),
                                         clock: -> { @store.now }, log: ConsoleFakes::Log.new)
  end

  def step(session, renderer, terminal, line)
    return state(session, line["state"]) if line.key?("state")
    return unless line.key?("renderer")

    type(terminal, line["renderer"])
    heard = renderer.next_line(patience: PATIENCE)
    @conversation << { "renderer" => JSON.parse(heard) }
    session.receive(heard)
  end

  def state(session, state)
    @store.runs = state["runs"].map { |run| JSON.parse(JSON.generate(run), symbolize_names: true) }
    @store.now = state["now"]
    @conversation.empty? ? session.start : session.refresh
  end

  # The key a `key` line says the renderer read, typed on the terminal.
  def type(terminal, message)
    terminal.write(TYPED.fetch(message["key"], message["key"])) if message["t"] == "key"
  end

  # [rows, cols] from the fixture's `ready`.
  def size
    ready = @lines.filter_map { |line| line["renderer"] }.find { |message| message["t"] == "ready" }
    [ready.fetch("rows"), ready.fetch("cols")]
  end

  # Reads what the binary draws, so it never blocks on a full terminal,
  # until the terminal is closed.
  def drain(terminal)
    loop { terminal.readpartial(4096) }
  rescue IOError, Errno::EIO
    nil
  end
end
