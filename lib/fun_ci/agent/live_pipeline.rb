# frozen_string_literal: true

require "rbconfig"
require_relative "../pipeline/run_canceller"
require_relative "../setup/project_config"

module FunCi
  module Agent
    # The project's pipeline, as `wait` starts and watches it and `cancel`
    # stops a job of it: a run starts the way the post-commit hook starts one,
    # with `fun-ci trigger --background` in a process of its own, rather than
    # as a fork of the waiting process and its open database connection.
    class LivePipeline
      FUN_CI = File.expand_path("../../../exe/fun-ci", __dir__)

      # command: what runs fun-ci, the gem's own executable by default.
      def initialize(project_dir, command: [RbConfig.ruby, FUN_CI])
        @project_dir = project_dir
        @command = command
      end

      # Answers the finished starter, or nil in a project not set up for fun-ci.
      def start(sha, branch)
        return unless Setup::ProjectConfig.new(@project_dir).validate.empty?

        pid = Process.spawn(*@command, "trigger", "--background", sha, branch,
                            chdir: @project_dir, %i[out err] => File::NULL)
        Process.detach(pid).join
      end

      # Records failed each slow suite and each daily or weekly job whose
      # process died (acceptance-tests.md, AT-8.3, AT-13.6).
      def watch(db)
        canceller = Pipeline::RunCanceller.new
        canceller.record_dead(db)
        canceller.record_dead_jobs(db)
      end

      # Stops a daily or weekly job's run and records it cancelled, as the console does.
      def cancel_job(db, id) = Pipeline::RunCanceller.new.cancel_job(db, id)
    end
  end
end
