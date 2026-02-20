# frozen_string_literal: true

module FunCi
  class TemplateWriter
    TEMPLATES = {
      ruby_bundler: {
        "lint.sh" => "#!/bin/sh\nbundle exec rubocop \"$1\"\n",
        "build.sh" => "#!/bin/sh\nbundle install --quiet\n",
        "fast.sh" => "#!/bin/sh\nbundle exec rake test \"$1\"\n",
        "slow.sh" => "#!/bin/sh\nbundle exec rake test:slow \"$1\"\n"
      },
      jvm_gradle_kotlin: {
        "lint.sh" => "#!/bin/sh\n./gradlew check -x test \"$1\"\n",
        "build.sh" => "#!/bin/sh\n./gradlew assemble\n",
        "fast.sh" => "#!/bin/sh\n./gradlew test \"$1\"\n",
        "slow.sh" => "#!/bin/sh\n./gradlew integrationTest \"$1\"\n"
      },
      jvm_gradle_groovy: {
        "lint.sh" => "#!/bin/sh\n./gradlew check -x test \"$1\"\n",
        "build.sh" => "#!/bin/sh\n./gradlew assemble\n",
        "fast.sh" => "#!/bin/sh\n./gradlew test \"$1\"\n",
        "slow.sh" => "#!/bin/sh\n./gradlew integrationTest \"$1\"\n"
      },
      jvm_maven: {
        "lint.sh" => "#!/bin/sh\nmvn verify -DskipTests \"$1\"\n",
        "build.sh" => "#!/bin/sh\nmvn compile\n",
        "fast.sh" => "#!/bin/sh\nmvn test \"$1\"\n",
        "slow.sh" => "#!/bin/sh\nmvn verify \"$1\"\n"
      }
    }.freeze

    def initialize(template_id, target_dir)
      @template_id = template_id
      @target_dir = target_dir
    end

    def write
      scripts = TEMPLATES.fetch(@template_id)
      fun_ci_dir = File.join(@target_dir, ".fun-ci")
      Dir.mkdir(fun_ci_dir)

      scripts.each do |name, content|
        path = File.join(fun_ci_dir, name)
        File.write(path, content)
        File.chmod(0o755, path)
      end
    end
  end
end
