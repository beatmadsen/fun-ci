# frozen_string_literal: true

module FunCi
  module Setup
    # The stage scripts `fun-ci init` writes, per kind of project. Test stages
    # copy the build's JUnit XML into FUN_CI_REPORT when fun-ci names one
    # (acceptance-tests.md, AT-9.8), and exit as the build did.
    module StageTemplates
      def self.reporting(command, *report_dirs)
        reports = report_dirs.map { |dir| "#{dir}/*.xml" }.join(" ")
        "#!/bin/sh\n#{command}\nstatus=$?\n" \
          "[ -n \"$FUN_CI_REPORT\" ] && cp #{reports} \"$FUN_CI_REPORT\" 2>/dev/null\nexit $status\n"
      end

      GRADLE = {
        "lint.sh" => "#!/bin/sh\n./gradlew check -x test\n",
        "build.sh" => "#!/bin/sh\n./gradlew assemble\n",
        "fast.sh" => reporting("./gradlew test", "build/test-results/test"),
        "slow.sh" => reporting("./gradlew integrationTest", "build/test-results/integrationTest")
      }.freeze

      TEMPLATES = {
        ruby_bundler: {
          "lint.sh" => "#!/bin/sh\nbundle exec rubocop\n",
          "build.sh" => "#!/bin/sh\nbundle install --quiet\n",
          "fast.sh" => "#!/bin/sh\nbundle exec rake test\n",
          "slow.sh" => "#!/bin/sh\nbundle exec rake test:slow\n"
        },
        jvm_gradle_kotlin: GRADLE,
        jvm_gradle_groovy: GRADLE,
        jvm_maven: {
          "lint.sh" => "#!/bin/sh\nmvn verify -DskipTests\n",
          "build.sh" => "#!/bin/sh\nmvn compile\n",
          "fast.sh" => reporting("mvn test", "target/surefire-reports"),
          "slow.sh" => reporting("mvn verify", "target/surefire-reports", "target/failsafe-reports")
        }
      }.freeze

      # { "lint.sh" => script, ... }; +lint_override+ replaces the lint command.
      def self.scripts(template_id, lint_override: nil)
        scripts = TEMPLATES.fetch(template_id)
        lint_override ? scripts.merge("lint.sh" => "#!/bin/sh\n#{lint_override}\n") : scripts
      end
    end
  end
end
