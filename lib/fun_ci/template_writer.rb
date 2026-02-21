# frozen_string_literal: true

module FunCi
  class TemplateWriter
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

    def initialize(template_id, target_dir, lint_override: nil)
      @template_id = template_id
      @target_dir = target_dir
      @lint_override = lint_override
    end

    def write
      scripts = TEMPLATES.fetch(@template_id)
      fun_ci_dir = File.join(@target_dir, ".fun-ci")
      Dir.mkdir(fun_ci_dir)

      scripts.each do |name, content|
        content = "#!/bin/sh\n#{@lint_override}\n" if name == "lint.sh" && @lint_override
        path = File.join(fun_ci_dir, name)
        File.write(path, content)
        File.chmod(0o755, path)
      end
    end
  end
end
