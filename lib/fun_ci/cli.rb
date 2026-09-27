# frozen_string_literal: true

require "fileutils"
require_relative "../fun_ci"
require_relative "cli_help"
require_relative "pipeline/trigger_params"
require_relative "persistence/state_dir"
require_relative "setup/commands"

module FunCi
  class Cli
    ROUTES = {
      "trigger" => :run_trigger,
      "console" => :run_console,
      "init" => :run_init,
      "install-hooks" => :run_install_hooks,
      "check" => :run_check,
      "prune" => :run_prune
    }.freeze
    AGENT_COMMANDS = %w[status runs wait events why].freeze

    def self.default_db_dir = Persistence::StateDir.path(ENV)

    def self.run(args, io: Pipeline::Io.new, handlers: {}, db_dir: default_db_dir)
      new(io: io, handlers: handlers, db_dir: db_dir).run(args)
    end

    def initialize(io:, handlers:, db_dir:)
      @io = io
      @db_dir = db_dir
      @handlers = handlers
    end

    def run(args)
      subcommand = args.first
      return help(0) if %w[-h --help].include?(subcommand)
      return version if subcommand == "--version"

      return unknown_command(subcommand) unless ROUTES.key?(subcommand) || AGENT_COMMANDS.include?(subcommand)

      dispatch(subcommand, args.drop(1))
    end

    private

    def dispatch(subcommand, args)
      return @handlers[subcommand].call(args) if @handlers.key?(subcommand)
      return run_agent(subcommand, args) if AGENT_COMMANDS.include?(subcommand)

      send(ROUTES[subcommand], args)
    end

    def run_trigger(args)
      require_relative "pipeline/trigger"
      require_relative "persistence/pipeline_recorder"
      db = setup_db
      recorder = Persistence::DbRecorder.new(db)
      Pipeline::Trigger.run_from_args(args, io: @io, recorder: recorder)
    end

    # Only `console` needs the renderer, so only it fails without one.
    def run_console(_args)
      require_relative "console/launcher"
      require_relative "console/renderer_lookup"
      launch_console(Console::RendererLookup.default.path)
    rescue Console::RendererLookup::Missing => e
      @io.stderr.puts e.message
      1
    end

    def launch_console(renderer)
      db = setup_db
      Console::Launcher.run(renderer: renderer, db: db, project_dir: Dir.pwd, stderr: @io.stderr)
    ensure
      db&.close
    end

    def run_agent(name, args)
      require_relative "agent/commands"
      db = setup_db
      Agent::Commands.run(name, args, agent_context(db))
    ensure
      db&.close
    end

    def agent_context(db)
      Agent::Context.new(db: db, git: Agent::Git.new(Dir.pwd), io: @io, clock: Agent::SystemClock.new,
                         pipeline: Agent::LivePipeline.new(Dir.pwd))
    end

    def run_init(args) = setup_commands.init(args)
    def run_install_hooks(args) = setup_commands.install_hooks(args)
    def run_check(args) = setup_commands.check(args)
    def setup_commands = Setup::Commands.new(Dir.pwd, @io.stdout)

    def run_prune(_args)
      require_relative "pipeline/worktree_prune"
      removed = Pipeline::WorktreePrune.new(Pipeline::Worktrees.new(Dir.pwd)).run
      @io.stdout.puts "Removed #{removed} fun-ci worktree#{"s" unless removed == 1}."
      0
    rescue Pipeline::WorktreePrune::Busy, Pipeline::Worktrees::GitError => e
      @io.stderr.puts "fun-ci prune: #{e.message}"
      1
    end

    def setup_db
      FileUtils.mkdir_p(@db_dir)
      db_path = File.join(@db_dir, "db.sqlite3")
      db = Persistence::Database.connection(db_path)
      Persistence::Database.migrate!(db)
      db
    end

    def help(exit_code)
      @io.stdout.puts CliHelp::TEXT
      exit_code
    end

    def version
      @io.stdout.puts "fun-ci #{FunCi::VERSION}"
      0
    end

    def unknown_command(subcommand)
      @io.stderr.puts "fun-ci: unknown command '#{subcommand}'", "" if subcommand
      @io.stderr.puts "Usage: fun-ci <command> [options]", "", "Run 'fun-ci --help' for available commands."
      1
    end
  end
end
