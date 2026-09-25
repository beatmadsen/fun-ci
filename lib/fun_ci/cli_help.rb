# frozen_string_literal: true

module FunCi
  module CliHelp
    TEXT = <<~HELP
      fun-ci - Opinionated, local-first CI for your projects

      Usage:
        fun-ci <command> [options]

      Commands:
        trigger        Run CI pipeline for a commit
        console        Launch the admin TUI dashboard
        init           Initialize .fun-ci/ with template scripts
        install-hooks  Install post-commit and pre-push git hooks
        check          Verify project setup

      Options:
        -h, --help     Show this help message
        --version      Show version

      Trigger options:
        --background   Run the pipeline in the background and return at once

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
