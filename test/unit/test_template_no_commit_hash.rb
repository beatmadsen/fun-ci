# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/template_writer"
require "tmpdir"

class TestTemplateNoCommitHash < Minitest::Test
  def test_should_not_pass_commit_hash_to_lint_commands
    # Given a target directory with ruby_bundler template
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:ruby_bundler, dir)

      # When we write the template
      writer.write

      # Then lint.sh should not pass $1 (rubocop doesn't accept commit hashes)
      content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert_match(/rubocop/, content, "Should use rubocop")
      refute_match(/\$1/, content, "lint.sh should not pass $1 to rubocop")
    end
  end

  def test_should_not_pass_commit_hash_to_gradle_lint_commands
    # Given a target directory with jvm_gradle_kotlin template
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:jvm_gradle_kotlin, dir)

      # When we write the template
      writer.write

      # Then lint.sh should not pass $1 (gradlew check doesn't accept commit hashes)
      content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert_match(/gradlew.*check/, content, "Should use gradlew check")
      refute_match(/\$1/, content, "lint.sh should not pass $1 to gradlew check")
    end
  end

  def test_should_not_pass_commit_hash_to_maven_lint_commands
    # Given a target directory with jvm_maven template
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:jvm_maven, dir)

      # When we write the template
      writer.write

      # Then lint.sh should not pass $1 (mvn verify doesn't accept commit hashes)
      content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert_match(/mvn.*verify/, content, "Should use mvn verify")
      refute_match(/\$1/, content, "lint.sh should not pass $1 to mvn verify")
    end
  end

  def test_should_not_pass_commit_hash_to_ruby_test_scripts
    # Given a target directory with ruby_bundler template
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:ruby_bundler, dir)

      # When we write the template
      writer.write

      # Then fast.sh and slow.sh should not pass $1 (rake test doesn't accept commit hashes)
      %w[fast.sh slow.sh].each do |script|
        content = File.read(File.join(dir, ".fun-ci", script))
        assert_match(/rake test/, content, "#{script} should use rake test")
        refute_match(/\$1/, content, "#{script} should not pass $1 to rake test")
      end
    end
  end

  def test_should_not_pass_commit_hash_to_gradle_test_scripts
    # Given a target directory with jvm_gradle_kotlin template
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:jvm_gradle_kotlin, dir)

      # When we write the template
      writer.write

      # Then fast.sh and slow.sh should not pass $1 (gradlew test doesn't accept commit hashes)
      %w[fast.sh slow.sh].each do |script|
        content = File.read(File.join(dir, ".fun-ci", script))
        assert_match(/gradlew/, content, "#{script} should use gradlew")
        refute_match(/\$1/, content, "#{script} should not pass $1 to gradlew")
      end
    end
  end

  def test_should_not_pass_commit_hash_to_maven_test_scripts
    # Given a target directory with jvm_maven template
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:jvm_maven, dir)

      # When we write the template
      writer.write

      # Then fast.sh and slow.sh should not pass $1 (mvn test/verify doesn't accept commit hashes)
      %w[fast.sh slow.sh].each do |script|
        content = File.read(File.join(dir, ".fun-ci", script))
        assert_match(/mvn/, content, "#{script} should use mvn")
        refute_match(/\$1/, content, "#{script} should not pass $1 to mvn")
      end
    end
  end
end
