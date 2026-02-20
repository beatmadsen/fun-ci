# frozen_string_literal: true

require_relative "database"
require_relative "pipeline_run"

module FunCi
  class StalePipelineCanceller
    def initialize(project_root:, branch:, commit_hash:, stdout:)
      @project_root = project_root
      @branch = branch
      @commit_hash = commit_hash
      @stdout = stdout
    end

    def cancel
      pid_file = pid_file_path
      return unless File.exist?(pid_file)

      lines = File.read(pid_file).strip.split("\n")
      old_pid = lines[0].to_i
      old_commit = lines[1]
      old_db_path = lines[2]
      old_run_id = lines[3]&.to_i
      return if old_pid <= 0

      begin
        Process.kill(0, old_pid)
      rescue Errno::ESRCH
        mark_cancelled(old_db_path, old_run_id)
        File.delete(pid_file) rescue nil
        return
      end

      Process.kill("TERM", old_pid) rescue nil
      Process.kill("KILL", old_pid) rescue nil
      Process.waitpid(old_pid) rescue nil
      mark_cancelled(old_db_path, old_run_id)
      File.delete(pid_file) rescue nil

      @stdout.puts "Cancelled stale pipeline for #{old_commit}. Starting fresh for #{@commit_hash}."
    end

    def write_pid_file(pid, db_path: nil, pipeline_run_id: nil)
      File.write(pid_file_path, "#{pid}\n#{@commit_hash}\n#{db_path}\n#{pipeline_run_id}")
    end

    def pid_file_path
      pid_dir = File.join(@project_root, ".fun-ci-pids")
      Dir.mkdir(pid_dir) unless Dir.exist?(pid_dir)
      File.join(pid_dir, "#{@branch}.pid")
    end

    private

    def mark_cancelled(db_path, run_id)
      return unless db_path && !db_path.empty? && run_id && run_id > 0
      db = Database.connection(db_path)
      PipelineRun.update_status(db, run_id, "cancelled")
      db.close
    end
  end
end
