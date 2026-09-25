# frozen_string_literal: true

module FunCi
  module Setup
    # The stage scripts `fun-ci init` writes, per kind of project.
    module StageTemplates
      TEMPLATES = {
        ruby_bundler: {
          "lint.sh" => "#!/bin/sh\nbundle exec rubocop\n",
          "build.sh" => "#!/bin/sh\nbundle install --quiet\n",
          "fast.sh" => "#!/bin/sh\nbundle exec rake test\n",
          "slow.sh" => "#!/bin/sh\nbundle exec rake test:slow\n"
        },
        jvm_gradle_kotlin: {
          "lint.sh" => "#!/bin/sh\n./gradlew check -x test\n",
          "build.sh" => "#!/bin/sh\n./gradlew assemble\n",
          "fast.sh" => "#!/bin/sh\n./gradlew test\n",
          "slow.sh" => "#!/bin/sh\n./gradlew integrationTest\n"
        },
        jvm_gradle_groovy: {
          "lint.sh" => "#!/bin/sh\n./gradlew check -x test\n",
          "build.sh" => "#!/bin/sh\n./gradlew assemble\n",
          "fast.sh" => "#!/bin/sh\n./gradlew test\n",
          "slow.sh" => "#!/bin/sh\n./gradlew integrationTest\n"
        },
        jvm_maven: {
          "lint.sh" => "#!/bin/sh\nmvn verify -DskipTests\n",
          "build.sh" => "#!/bin/sh\nmvn compile\n",
          "fast.sh" => "#!/bin/sh\nmvn test\n",
          "slow.sh" => "#!/bin/sh\nmvn verify\n"
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
