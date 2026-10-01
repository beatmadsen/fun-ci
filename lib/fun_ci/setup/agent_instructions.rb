# frozen_string_literal: true

module FunCi
  module Setup
    # What `fun-ci init` tells a coding agent working in the project, in the
    # instructions file agents read (acceptance-tests.md, AT-9.15): AGENTS.md,
    # or CLAUDE.md when that is the only one. The marker keeps it to once.
    module AgentInstructions
      MARKER = "<!-- fun-ci: agent instructions -->"
      SECTION = <<~MD.freeze
        ## fun-ci

        #{MARKER}
        This project runs fun-ci on every commit. After each commit, run the
        `fun-ci wait` command it prints, in the background, and act on its exit
        code: 0 passed, 1 failed, 2 over budget, 3 undecided. A newer commit on
        the branch cancels the run and the wait moves on to the newer one's.
        `fun-ci wait --need all` must exit 0 before the work is called done.
        Before calling work done, run `fun-ci wait --need all --trunk`; 6 means
        the commit conflicts with the trunk, which has to be integrated first,
        as it prints.
        `fun-ci runs` lists recent runs, and `fun-ci status` says where one stands.
        `fun-ci jobs` lists the daily and weekly jobs, which run beside the
        pipeline and never hold up a verdict, and `fun-ci why --job NAME` says
        why one failed.
      MD

      def self.file_for(names) = names.include?("CLAUDE.md") && !names.include?("AGENTS.md") ? "CLAUDE.md" : "AGENTS.md"

      # The text with the section added, or nil when it has it already.
      def self.merged(text)
        return nil if text.include?(MARKER)

        text.strip.empty? ? SECTION : "#{text.rstrip}\n\n#{SECTION}"
      end
    end
  end
end
