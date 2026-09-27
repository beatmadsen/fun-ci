# frozen_string_literal: true

require "open3"
require_relative "../pipeline/git_environment"

module FunCi
  module Agent
    # The project's git, as agent commands ask it: which commit a revision
    # names, that commit's subject, and the directory the project is in.
    class Git
      def initialize(dir)
        @dir = dir
      end

      def resolve(rev) = git("rev-parse", "--verify", "--quiet", "#{rev}^{commit}")
      def subject(sha) = git("log", "-1", "--format=%s", sha).to_s
      def toplevel = File.realpath(git("rev-parse", "--show-toplevel"))

      private

      # Its first line of output, or nil when git fails.
      def git(*)
        output, status = Open3.capture2(Pipeline::GitEnvironment::CLEAN, "git", *, chdir: @dir, err: File::NULL)
        status.success? ? output.lines.first&.chomp : nil
      end
    end
  end
end
