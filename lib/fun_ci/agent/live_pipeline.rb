# frozen_string_literal: true

require "rbconfig"
require_relative "../pipeline/run_canceller"

module FunCi
  module Agent
    # The project's pipeline, as `wait` starts and watches it: a run starts
    # the way the post-commit hook starts one, with `fun-ci trigger
    # --background` in a process of its own, rather than as a fork of the
    # waiting process and its open database connection.
    class LivePipeline
      FUN_CI = File.expand_path("../../../exe/fun-ci", __dir__)

      def initialize(project_dir)
        @project_dir = project_dir
      end

      def start(sha, branch)
        pid = Process.spawn(RbConfig.ruby, FUN_CI, "trigger", "--background", sha, branch,
                            chdir: @project_dir, %i[out err] => File::NULL)
        Process.detach(pid).join
      end

      # Records failed each slow suite whose process died (acceptance-tests.md, AT-8.3).
      def watch(db) = Pipeline::RunCanceller.new.record_dead(db)
    end
  end
end
