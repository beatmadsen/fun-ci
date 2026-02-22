# frozen_string_literal: true

require "tmpdir"
require_relative "../fun_ci"

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
      unless ROUTES.key?(subcommand)
        print_error(subcommand)
        return 1
      end
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
      Pipeline::Trigger.run_from_args(args, stdout: @stdout, stderr: @stderr, recorder: recorder)
    end

    def run_console(_args)
      require_relative "tui/admin_tui"
      require_relative "tui/animation_renderer"
      require "io/console"
      db = setup_db
      tui = Tui::AdminTui.new(
        db: db,
        width_provider: -> { IO.console&.winsize&.dig(1) || 80 },
        height_provider: -> { IO.console&.winsize&.dig(0) },
        animation_renderer: Tui::AnimationRenderer.new
      )
      tui.run
      0
    end

    def run_init(args)
      require_relative "setup/installer"
      code = Setup::Installer.run(project_root: Dir.pwd, stdout: @stdout)
      return code if code != 0 || !args.include?("--everything")
      code = run_install_hooks([])
      return code unless code == 0
      run_check([])
    end

    def run_install_hooks(args)
      require_relative "setup/hook_writer"
      types = args.any? ? [args.first] : %w[pre-commit pre-push]
      types.each do |type|
        code = Setup::HookWriter.run(project_root: Dir.pwd, hook_type: type, stdout: @stdout)
        return code unless code == 0
      end
      0
    end

    def run_check(_args)
      require_relative "setup/setup_checker"
      Setup::SetupChecker.run(project_root: Dir.pwd, stdout: @stdout, stderr: @stderr)
    end

    def setup_db
      db_dir = File.join(Dir.tmpdir, "fun-ci")
      Dir.mkdir(db_dir) unless Dir.exist?(db_dir)
      db_path = File.join(db_dir, "db.sqlite3")
      db = Persistence::Database.connection(db_path)
      Persistence::Database.migrate!(db)
      db
    end

    HELP_TEXT = <<~HELP
      fun-ci - Opinionated, local-first CI for your projects

      Usage:
        fun-ci <command> [options]

      Commands:
        trigger        Run CI pipeline for a commit
        console        Launch the admin TUI dashboard
        init           Initialize .fun-ci/ with template scripts
        install-hooks  Install pre-commit and pre-push git hooks
        check          Verify project setup

      Options:
        -h, --help     Show this help message
        --version      Show version

      Trigger options:
        --no-validate  Fork pipeline to background and return immediately

      Init options:
        --everything   Run init + install-hooks + check in one step

      Examples:
        fun-ci init --everything
        fun-ci trigger abc1234 main
        fun-ci trigger --no-validate abc1234 main
        fun-ci console
    HELP

    def help(exit_code)
      @stdout.puts HELP_TEXT
      exit_code
    end

    def version
      @stdout.puts "fun-ci #{FunCi::VERSION}"
      0
    end

    def print_error(subcommand)
      if subcommand
        @stderr.puts "fun-ci: unknown command '#{subcommand}'"
        @stderr.puts ""
      end
      @stderr.puts "Usage: fun-ci <command> [options]"
      @stderr.puts ""
      @stderr.puts "Run 'fun-ci --help' for available commands."
    end
  end
end
