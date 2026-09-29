# frozen_string_literal: true

module FunCi
  module Agent
    # What to do about a conflict with the trunk, built from the trunk that was
    # resolved: a pull that fetches first, so the trunk integrated is never
    # older than the one checked. A rebase of a pushed branch needs a force
    # push, so off the trunk branch a merge comes first.
    module NextStep
      def self.line(tip, files, branch:)
        count = files.size == 1 ? "1 file" : "#{files.size} files"
        "Conflicts with #{tip.ref} in #{count}. When the task is done, integrate: #{command(tip, branch)}"
      end

      def self.command(tip, branch)
        return "git merge #{tip.branch}" unless tip.remote

        pull = "#{tip.remote} #{tip.branch}"
        return "git pull --rebase #{pull}" if branch == tip.branch

        "git pull #{pull} (or git pull --rebase #{pull} if the branch isn't shared)"
      end
      private_class_method :command
    end
  end
end
