# frozen_string_literal: true

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

      old_pid, old_commit = File.read(pid_file).strip.split("\n")
      old_pid = old_pid.to_i
      return if old_pid <= 0

      begin
        Process.kill(0, old_pid)
      rescue Errno::ESRCH
        File.delete(pid_file) rescue nil
        return
      end

      Process.kill("TERM", old_pid) rescue nil
      Process.kill("KILL", old_pid) rescue nil
      Process.waitpid(old_pid) rescue nil
      File.delete(pid_file) rescue nil

      @stdout.puts "Cancelled stale pipeline for #{old_commit}. Starting fresh for #{@commit_hash}."
    end

    def write_pid_file(pid)
      File.write(pid_file_path, "#{pid}\n#{@commit_hash}")
    end

    def pid_file_path
      pid_dir = File.join(@project_root, ".fun-ci-pids")
      Dir.mkdir(pid_dir) unless Dir.exist?(pid_dir)
      File.join(pid_dir, "#{@branch}.pid")
    end
  end
end
