# frozen_string_literal: true

module FunCi
  # What `fun-ci --help` and `fun-ci --version` print; each answers the exit code.
  module CliHelp
    def self.help(out)
      out.puts TEXT
      0
    end

    def self.version(out)
      out.puts "fun-ci #{FunCi::VERSION}"
      0
    end

    TEXT = <<~HELP
      fun-ci - Opinionated, local-first CI for your projects

      Usage:
        fun-ci <command> [options]

      Commands:
        trigger        Run CI pipeline for a commit
        console        Watch your runs as they happen, in the terminal
        init           Initialize .fun-ci/ with template scripts
        install-hooks  Install post-commit and pre-push git hooks
        check          Verify project setup
        prune          Remove fun-ci's worktrees when no pipeline is running
        status         Say where a commit's run stands, as an exit code an agent can act on
        runs           List this project's recent runs, newest first
        wait           Wait for a commit's verdict, then exit with it as status does
        events         Print this project's runs' events as JSON lines
        why            Print everything kept about why a commit's stage failed, or its conflict with the trunk
        extract        Try a stage's evidence extractors on a saved output

      Options:
        -h, --help     Show this help message
        --version      Show version

      Trigger options:
        --background   Run the pipeline in the background and return at once

      Agent options:
        --need LEVEL   (status, wait, why) What must pass: build, fast (default) or all
        --within TIME  (wait) Give up undecided after 30, 30s or 5m
        --follow-branch  (wait) Move on to the newer commit that superseded the run
        --trunk        (status, wait) Exit 6 when the run passed but conflicts with the trunk
        --raw          (why) Print the stage's whole output as it was kept
        -n N           (runs) How many runs to list (default 10)
        --branch NAME  (runs) Only runs on this branch
        --follow       (events) Keep printing events as they happen, until stopped
        --only failures  (events) Print only failed stages and superseded runs
        --json         Print JSON instead of text (events always print JSON lines)
        Exit codes: 0 passed, 1 failed, 2 over budget, 3 undecided,
        4 superseded, 5 no run, 6 conflicts with the trunk (--trunk), 64 usage error

      Init options:
        --everything   Run init + install-hooks + check in one step

      Examples:
        fun-ci init --everything
        fun-ci trigger abc1234 main
        fun-ci trigger --background abc1234 main
        fun-ci console
    HELP
  end
end
