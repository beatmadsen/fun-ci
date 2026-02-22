# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "tmpdir"
require "stringio"

class TestInitCliRubyProject < Minitest::Test
  def test_should_create_executable_scripts_for_ruby_project
    # Given a project directory with a Gemfile
    Dir.mktmpdir("fun-ci-init-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new

      # When we run init
      exit_code = FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then it should succeed and create all four executable scripts
      assert_equal 0, exit_code, "Should return success exit code"
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        path = File.join(dir, ".fun-ci", script)
        assert File.exist?(path), "#{script} should exist"
        assert File.executable?(path), "#{script} should be executable"
      end

      # And the scripts should be Ruby/Bundler templates
      content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert_match(/bundle exec/, content, "Ruby template should use bundler")
    end
  end
end

class TestInitCliGradleKotlinProject < Minitest::Test
  def test_should_create_executable_scripts_for_gradle_kotlin_project
    # Given a project directory with build.gradle.kts
    Dir.mktmpdir("fun-ci-init-test") do |dir|
      File.write(File.join(dir, "build.gradle.kts"), "plugins { kotlin(\"jvm\") }\n")
      stdout = StringIO.new

      # When we run init
      exit_code = FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then it should succeed and create all four executable scripts
      assert_equal 0, exit_code, "Should return success exit code"
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        path = File.join(dir, ".fun-ci", script)
        assert File.exist?(path), "#{script} should exist"
        assert File.executable?(path), "#{script} should be executable"
      end

      # And the scripts should be Gradle templates
      content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert_match(/gradlew/, content, "Gradle template should use gradlew")
    end
  end
end

class TestInitCliMavenProject < Minitest::Test
  def test_should_create_executable_scripts_for_maven_project
    # Given a project directory with pom.xml
    Dir.mktmpdir("fun-ci-init-test") do |dir|
      File.write(File.join(dir, "pom.xml"), "<project></project>\n")
      stdout = StringIO.new

      # When we run init
      exit_code = FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then it should succeed and create all four executable scripts
      assert_equal 0, exit_code, "Should return success exit code"
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        path = File.join(dir, ".fun-ci", script)
        assert File.exist?(path), "#{script} should exist"
        assert File.executable?(path), "#{script} should be executable"
      end

      # And the scripts should be Maven templates
      content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert_match(/mvn/, content, "Maven template should use mvn")
    end
  end
end

class TestInitCliUnknownProject < Minitest::Test
  def test_should_refuse_when_project_type_is_unknown
    # Given a project directory with no recognized marker files
    Dir.mktmpdir("fun-ci-init-test") do |dir|
      File.write(File.join(dir, "README.md"), "# Hello\n")
      stdout = StringIO.new

      # When we run init
      exit_code = FunCi::Setup::Installer.run(project_root: dir, stdout: stdout)

      # Then it should refuse
      assert_equal 1, exit_code, "Should return failure for unknown project type"
      assert_match(/could not detect|unknown/i, stdout.string, "Should explain the failure")
    end
  end
end
