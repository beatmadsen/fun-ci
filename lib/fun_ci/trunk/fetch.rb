# frozen_string_literal: true

require "shellwords"
require_relative "../pipeline/process_runner"
require_relative "resolver"

module FunCi
  module Trunk
    # How a fetch of the trunk went: nil error when it fetched.
    Fetched = Data.define(:error)

    # Fetches the trunk into a ref of fun-ci's own (architecture.md, Checking against the trunk,
    # Keeping the trunk fresh). An empty refmap keeps git from moving the
    # developer's remote-tracking ref too, and nothing may ask them anything:
    # ssh runs in batch mode unless they have an ssh command of their own.
    # Started in one thread, so its pid can be recorded, and finished in
    # another, killed with its process group at the deadline.
    class Fetch
      QUIET = { "GIT_TERMINAL_PROMPT" => "0", "SSH_ASKPASS_REQUIRE" => "never", "GCM_INTERACTIVE" => "never" }.freeze
      NO_PROMPT_SSH = 'if [ -z "$GIT_SSH_COMMAND" ] && ! git config --get core.sshCommand >/dev/null; then ' \
                      'export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"; fi; '
      OPTIONS = %w[--quiet --no-tags --no-write-fetch-head --no-recurse-submodules --no-auto-maintenance
                   --refmap=].freeze

      def self.ref_for(ref) = "refs/fun-ci/trunk/#{ref.remote}/#{ref.branch}"

      # env: what the fetch finds in its environment besides fun-ci's own.
      def initialize(dir, env:)
        @launch = Pipeline::ProcessRunner::Launch.new(chdir: dir, env: QUIET.merge(env))
        @runner = Object.new.extend(Pipeline::ProcessRunner)
      end

      # Yields the fetch's pid before it runs.
      def start(ref, &) = @runner.start_process(command(ref), @launch, &)

      def finish(started, deadline:, timer: Pipeline::ProcessRunner::BUDGET)
        output, status, over = @runner.await_process(started, deadline, launch: @launch, timer: timer)
        return Fetched.new(error: "no answer within #{deadline} s") if over

        Fetched.new(error: status.success? ? nil : reason(output))
      end

      private

      def command(ref)
        refspec = "+refs/heads/#{ref.branch}:#{self.class.ref_for(ref)}"
        fetch = Shellwords.join(["git", "fetch", *OPTIONS, ref.remote, refspec])
        "sh -c #{Shellwords.escape("#{NO_PROMPT_SSH}exec #{fetch}")}"
      end

      def reason(output)
        lines = output.lines.map(&:strip).reject(&:empty?)
        (lines.find { |line| line.start_with?("fatal:") } || lines.first || "git fetch failed").to_s
      end
    end
  end
end
