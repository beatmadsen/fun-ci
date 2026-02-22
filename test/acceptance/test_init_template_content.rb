# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "tmpdir"
require "stringio"

class TestInitTemplateContentRuby < Minitest::Test
  def test_should_not_pass_commit_hash_to_rubocop_in_lint_script
    # Given a Ruby project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then lint.sh should NOT pass $1 to rubocop (rubocop doesn't accept a commit hash)
      content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert_match(/rubocop/, content, "Should use rubocop")
      refute_match(/rubocop.*\$1/, content, "Should not pass $1 to rubocop")
    end
  end

  def test_should_not_pass_commit_hash_to_bundle_install_in_build_script
    # Given a Ruby project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then build.sh should NOT pass $1 (bundle install doesn't use commit hashes)
      content = File.read(File.join(dir, ".fun-ci", "build.sh"))
      assert_match(/bundle install/, content, "Should use bundle install")
      refute_match(/\$1/, content, "Should not pass $1 to bundle install")
    end
  end
end

class TestInitTemplateContentGradle < Minitest::Test
  def test_should_not_pass_commit_hash_to_gradlew_check_in_lint_script
    # Given a Gradle Kotlin project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "build.gradle.kts"), "plugins { kotlin(\"jvm\") }\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then lint.sh should NOT pass $1 to gradlew check
      content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert_match(/gradlew.*check/, content, "Should use gradlew check")
      refute_match(/\$1/, content, "Should not pass $1 to gradlew check")
    end
  end

  def test_should_not_pass_commit_hash_to_gradlew_assemble_in_build_script
    # Given a Gradle Kotlin project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "build.gradle.kts"), "plugins { kotlin(\"jvm\") }\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then build.sh should NOT pass $1 (gradlew assemble doesn't use commit hashes)
      content = File.read(File.join(dir, ".fun-ci", "build.sh"))
      assert_match(/gradlew.*assemble/, content, "Should use gradlew assemble")
      refute_match(/\$1/, content, "Should not pass $1 to gradlew assemble")
    end
  end
end

class TestInitTemplateContentMaven < Minitest::Test
  def test_should_not_pass_commit_hash_to_mvn_verify_in_lint_script
    # Given a Maven project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "pom.xml"), "<project></project>\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then lint.sh should NOT pass $1 to mvn verify -DskipTests
      content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert_match(/mvn.*verify/, content, "Should use mvn verify")
      refute_match(/\$1/, content, "Should not pass $1 to mvn verify")
    end
  end

  def test_should_not_pass_commit_hash_to_mvn_compile_in_build_script
    # Given a Maven project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "pom.xml"), "<project></project>\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then build.sh should NOT pass $1 (mvn compile doesn't use commit hashes)
      content = File.read(File.join(dir, ".fun-ci", "build.sh"))
      assert_match(/mvn.*compile/, content, "Should use mvn compile")
      refute_match(/\$1/, content, "Should not pass $1 to mvn compile")
    end
  end

  def test_should_use_detected_linter_when_pom_contains_linter_plugin
    # Given a Maven project with detekt in pom.xml
    Dir.mktmpdir("fun-ci-maven-linter-acc") do |dir|
      pom_content = <<~XML
        <project>
          <build><plugins>
            <plugin><artifactId>detekt-maven-plugin</artifactId></plugin>
          </plugins></build>
        </project>
      XML
      File.write(File.join(dir, "pom.xml"), pom_content)
      stdout = StringIO.new

      # When we run init (no DI — reads real pom.xml)
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then lint.sh should use the detected linter, not the default
      lint_content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert_match(/mvn detekt:check/, lint_content, "Should use detected detekt command")
      refute_match(/verify/, lint_content, "Should not contain default mvn verify")
    end
  end
end
