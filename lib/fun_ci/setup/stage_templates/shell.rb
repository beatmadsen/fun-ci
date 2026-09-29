# frozen_string_literal: true

module FunCi
  module Setup
    # What every stack's stage scripts are made of.
    module StageTemplates
      def self.script(body) = "#!/bin/sh\n#{body}\n"

      # A command that copies the build's JUnit XML into FUN_CI_REPORT when
      # fun-ci names one (AT-9.8), and exits as the build did.
      def self.reporting(command, *report_dirs)
        reports = report_dirs.map { |dir| "#{dir}/*.xml" }.join(" ")
        "#{command}\nstatus=$?\n[ -n \"$FUN_CI_REPORT\" ] && cp #{reports} \"$FUN_CI_REPORT\" 2>/dev/null\nexit $status"
      end

      def self.stages(lint, build, fast, slow)
        { "lint.sh" => lint, "build.sh" => build, "fast.sh" => fast, "slow.sh" => slow }.transform_values do |body|
          script(body)
        end
      end
    end
  end
end
