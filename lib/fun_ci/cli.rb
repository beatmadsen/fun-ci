# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../fun_ci"
require_relative "cli_help"

module FunCi
  class Cli
    ROUTES = {
      "trigger" => :run_trigger,
      "console" => :run_console,
      "init" => :run_init,
      "install-hooks" => :run_install_hooks,
      "check" => :run_check
    }.freeze

    def self.run(args, stdout: $stdout, stderr: $stderr, handlers: {})
      new(stdout: stdout, stderr: stderr, handlers: handlers).run(args)
    end

    def initialize(stdout:, stderr:, handlers:)
      @stdout = stdout
      @stderr = stderr
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
      Pipeline::Trigger.run_from_args(args, io: Pipeline::Io.new(stdout: @stdout, stderr: @stderr), recorder: recorder)
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
      require_relative "setup/installer"
      code = Setup::Installer.run(project_root: Dir.pwd, stdout: @stdout)
      return code if !code.zero? || !args.include?("--everything")

      code = run_install_hooks([])
      return code unless code.zero?

      run_check([])
    end

    def run_install_hooks(args)
      require_relative "setup/hook_writer"
      types = args.any? ? [args.first] : %w[pre-commit pre-push]
      types.each do |type|
        code = Setup::HookWriter.run(project_root: Dir.pwd, hook_type: type, stdout: @stdout)
        return code unless code.zero?
      end
      0
    end

    def run_check(_args)
      require_relative "setup/setup_checker"
      Setup::SetupChecker.run(project_root: Dir.pwd, stdout: @stdout)
    end

    def setup_db
      db_dir = File.join(Dir.tmpdir, "fun-ci")
      FileUtils.mkdir_p(db_dir)
      db_path = File.join(db_dir, "db.sqlite3")
      db = Persistence::Database.connection(db_path)
      Persistence::Database.migrate!(db)
      db
    end

    def help(exit_code)
      @stdout.puts CliHelp::TEXT
      exit_code
    end

    def version
      @stdout.puts "fun-ci #{FunCi::VERSION}"
      0
    end

    def unknown_command(subcommand)
      @stderr.puts "fun-ci: unknown command '#{subcommand}'", "" if subcommand
      @stderr.puts "Usage: fun-ci <command> [options]", "", "Run 'fun-ci --help' for available commands."
      1
    end
  end
end
