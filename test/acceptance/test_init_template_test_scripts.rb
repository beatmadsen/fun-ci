# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "tmpdir"
require "stringio"

class TestInitTemplateTestScriptsRuby < Minitest::Test
  def test_should_not_pass_commit_hash_to_rake_test_in_fast_script
    # Given a Ruby project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then fast.sh should NOT pass $1 (rake test doesn't accept a commit hash)
      content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert_match(/rake test/, content, "Should use rake test")
      refute_match(/\$1/, content, "Should not pass $1 to rake test")
    end
  end

  def test_should_not_pass_commit_hash_to_rake_test_slow_in_slow_script
    # Given a Ruby project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then slow.sh should NOT pass $1 (rake test:slow doesn't accept a commit hash)
      content = File.read(File.join(dir, ".fun-ci", "slow.sh"))
      assert_match(/rake test/, content, "Should use rake test")
      refute_match(/\$1/, content, "Should not pass $1 to rake test:slow")
    end
  end
end

class TestInitTemplateTestScriptsGradle < Minitest::Test
  def test_should_not_pass_commit_hash_to_gradlew_test_in_fast_script
    # Given a Gradle Kotlin project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "build.gradle.kts"), "plugins { kotlin(\"jvm\") }\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then fast.sh should NOT pass $1 (gradlew test doesn't accept a commit hash)
      content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert_match(/gradlew.*test/, content, "Should use gradlew test")
      refute_match(/\$1/, content, "Should not pass $1 to gradlew test")
    end
  end

  def test_should_not_pass_commit_hash_to_gradlew_integration_test_in_slow_script
    # Given a Gradle Kotlin project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "build.gradle.kts"), "plugins { kotlin(\"jvm\") }\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then slow.sh should NOT pass $1 (gradlew integrationTest doesn't accept a commit hash)
      content = File.read(File.join(dir, ".fun-ci", "slow.sh"))
      assert_match(/gradlew.*integrationTest/, content, "Should use gradlew integrationTest")
      refute_match(/\$1/, content, "Should not pass $1 to gradlew integrationTest")
    end
  end
end

class TestInitTemplateTestScriptsMaven < Minitest::Test
  def test_should_not_pass_commit_hash_to_mvn_test_in_fast_script
    # Given a Maven project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "pom.xml"), "<project></project>\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then fast.sh should NOT pass $1 (mvn test doesn't accept a commit hash)
      content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert_match(/mvn.*test/, content, "Should use mvn test")
      refute_match(/\$1/, content, "Should not pass $1 to mvn test")
    end
  end

  def test_should_not_pass_commit_hash_to_mvn_verify_in_slow_script
    # Given a Maven project directory
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, "pom.xml"), "<project></project>\n")
      stdout = StringIO.new

      # When we run init
      FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then slow.sh should NOT pass $1 (mvn verify doesn't accept a commit hash)
      content = File.read(File.join(dir, ".fun-ci", "slow.sh"))
      assert_match(/mvn.*verify/, content, "Should use mvn verify")
      refute_match(/\$1/, content, "Should not pass $1 to mvn verify")
    end
  end
end
