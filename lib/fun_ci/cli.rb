# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../fun_ci"
require_relative "cli_help"
require_relative "pipeline/trigger_params"
require_relative "setup/installer"
require_relative "setup/hook_writer"
require_relative "setup/setup_checker"

module FunCi
  class Cli
    ROUTES = {
      "trigger" => :run_trigger,
      "console" => :run_console,
      "init" => :run_init,
      "install-hooks" => :run_install_hooks,
      "check" => :run_check
    }.freeze

    def self.default_db_dir = File.join(Dir.tmpdir, "fun-ci")

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

      return unknown_command(subcommand) unless ROUTES.key?(subcommand)

      dispatch(subcommand, args.drop(1))
    end

    private

    def dispatch(subcommand, args)
      return @handlers[subcommand].call(args) if @handlers.key?(subcommand)

      send(ROUTES[subcommand], args)
    end

    def run_trigger(args)
      require_relative "pipeline/trigger"
      require_relative "persistence/pipeline_recorder"
      db = setup_db
      recorder = Persistence::DbRecorder.new(db)
      Pipeline::Trigger.run_from_args(args, io: @io, recorder: recorder)
    end

    def run_console(_args)
      require_relative "tui/admin_tui"
      require_relative "tui/animation_renderer"
      require "io/console"
      admin_tui(setup_db).run
      0
    end

    def admin_tui(db)
      Tui::AdminTui.new(db: db, width_provider: -> { IO.console&.winsize&.dig(1) || 80 },
                        height_provider: -> { IO.console&.winsize&.dig(0) },
                        animation_renderer: Tui::AnimationRenderer.new)
    end

    def run_init(args)
      code = Setup::Installer.run(project_root: Dir.pwd, stdout: @io.stdout)
      return code if !code.zero? || !args.include?("--everything")

      code = run_install_hooks([])
      return code unless code.zero?

      run_check([])
    end

    def run_install_hooks(args)
      types = args.any? ? [args.first] : Setup::HookScript.types
      types.each do |type|
        code = Setup::HookWriter.run(project_root: Dir.pwd, hook_type: type, stdout: @io.stdout)
        return code unless code.zero?
      end
      0
    end

    def run_check(_args)
      Setup::SetupChecker.run(project_root: Dir.pwd, stdout: @io.stdout)
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
