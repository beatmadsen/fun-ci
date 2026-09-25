# frozen_string_literal: true

# A spawn call read as a git command: which subcommand, and the directory it
# works on. Open3 hands spawn its options as a trailing positional Hash.
class GitCommand
  def initialize(args, opts)
    hashes, command = args.partition { |arg| arg.is_a?(Hash) }
    @words = command.flat_map { |arg| arg.to_s.split }
    @chdir = hashes.reduce(opts) { |all, hash| all.merge(hash) }[:chdir]
  end

  def git? = @words.first == "git"
  def subcommand = @words[1].to_s
  def directory = File.expand_path(init_target, flag_value("-C") || @chdir || Dir.pwd)

  private

  def flag_value(flag) = @words.each_cons(2).find { |given, _| given == flag }&.last

  # `git init <dir>` works on <dir>, not on the directory it runs in.
  def init_target
    init_with_target = subcommand == "init" && @words.size > 2 && !@words.last.start_with?("-")
    init_with_target ? @words.last : "."
  end
end
