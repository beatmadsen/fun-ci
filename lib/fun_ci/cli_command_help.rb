# frozen_string_literal: true

require_relative "cli_help"

module FunCi
  # What `fun-ci COMMAND --help` prints in place of running the command: its
  # usage, what it is for and the options it takes, the last two read from
  # `fun-ci --help`, whose options name in brackets the commands taking them.
  module CliCommandHelp
    FLAGS = %w[-h --help].freeze
    USAGES = {
      "trigger" => "fun-ci trigger [--background] <commit-hash> <branch>",
      "console" => "fun-ci console",
      "init" => "fun-ci init [--everything] [--stack NAME]",
      "install-hooks" => "fun-ci install-hooks [post-commit | pre-push]",
      "check" => "fun-ci check",
      "prune" => "fun-ci prune",
      "status" => "fun-ci status [REV] [--need LEVEL] [--trunk] [--json]",
      "wait" => "fun-ci wait [REV] [--need LEVEL] [--within TIME] [--follow-branch] [--trunk] [--json]",
      "runs" => "fun-ci runs [-n N] [--branch NAME] [--json]",
      "events" => "fun-ci events [--follow] [--only failures]",
      "why" => "fun-ci why [REV] [STAGE | trunk] [--need LEVEL] [--raw] [--json]\n       " \
               "fun-ci why --job NAME [--raw] [--json]",
      "jobs" => "fun-ci jobs [--json]",
      "cancel" => "fun-ci cancel --job NAME",
      "extract" => "fun-ci extract STAGE --output FILE [--exit N | --timed-out] [--json]"
    }.freeze

    def self.asked?(args) = args.any? { |arg| FLAGS.include?(arg) }

    def self.help(out, command)
      out.puts "Usage: #{USAGES.fetch(command)}", "", purpose(command)
      options = options_of(command)
      out.puts "", "Options:", *options unless options.empty?
      0
    end

    def self.purpose(command) = CliHelp::TEXT[/^  #{Regexp.escape(command)} +(.+)$/, 1]

    def self.options_of(command)
      lines = CliHelp::TEXT.lines.select { |line| takes?(line, command) }
      lines.map { |line| line.sub(/\([^)]+\) /, "") }
    end

    def self.takes?(option_line, command)
      commands = option_line[/^\s+-\S.*?\(([^)]+)\)/, 1]
      !commands.nil? && commands.split(", ").include?(command)
    end
    private_class_method :purpose, :options_of, :takes?
  end
end
