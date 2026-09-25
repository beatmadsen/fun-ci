# frozen_string_literal: true

require "sqlite3"
require "open3"
require_relative "git_command"

# The calls ConfinementGuard watches: writing files, opening SQLite
# databases and running git.
module ConfinementHooks
  WRITE_FLAGS = File::WRONLY | File::RDWR | File::CREAT | File::APPEND | File::TRUNC

  # Which arguments of each File method are paths.
  PATH_ARGUMENTS = { write: 0..0, binwrite: 0..0, delete: 0.., unlink: 0.., chmod: 1.. }.freeze

  module FileWrites
    PATH_ARGUMENTS.each do |name, paths|
      define_method(name) do |*args, **opts, &block|
        ConfinementHooks.check_paths(args[paths], name)
        super(*args, **opts, &block)
      end
    end

    def open(path, mode = "r", *rest, **opts, &)
      ConfinementGuard.check(path, "open #{path} for writing") if ConfinementHooks.writing?(mode, opts)
      super
    end

    def rename(from, to)
      [from, to].each { |path| ConfinementGuard.check(path, "rename #{path}") }
      super
    end
  end

  module DirWrites
    %i[mkdir rmdir].each do |name|
      define_method(name) do |path, *rest|
        ConfinementGuard.check(path, "#{name} #{path}")
        super(path, *rest)
      end
    end
  end

  module SqliteOpens
    def initialize(file, ...)
      ConfinementGuard.check(file, "SQLite database #{file}") unless ConfinementHooks.in_memory?(file)
      super
    end
  end

  module GitSpawns
    %i[spawn system].each do |name|
      define_method(name) do |*args, **opts|
        ConfinementHooks.check_git(args, opts)
        super(*args, **opts)
      end
    end

    def `(command)
      ConfinementHooks.check_git([command], {})
      super
    end
  end

  class << self
    def install
      File.singleton_class.prepend(FileWrites)
      Dir.singleton_class.prepend(DirWrites)
      SQLite3::Database.prepend(SqliteOpens)
      [Kernel, Process.singleton_class].each { |target| target.prepend(GitSpawns) }
      @installed = true
    end

    def installed? = @installed == true
    def check_paths(paths, action) = paths.each { |path| ConfinementGuard.check(path, "#{action} #{path}") }
    def in_memory?(file) = file.to_s.empty? || file.to_s.start_with?(":memory:")

    def writing?(mode, opts)
      mode = opts.fetch(:mode, mode)
      mode.is_a?(Integer) ? mode.anybits?(WRITE_FLAGS) : mode.to_s.match?(/[wa+]/)
    end

    def check_git(args, opts)
      command = GitCommand.new(args, opts)
      ConfinementGuard.check(command.directory, "git #{command.subcommand}") if command.git?
    end
  end
end
