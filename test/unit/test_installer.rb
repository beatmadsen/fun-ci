# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/installer"
require "tmpdir"
require "stringio"

class TestInstallerHappyPath < Minitest::Test
  def test_should_report_detected_language_to_stdout
    # Given a Ruby project directory
    Dir.mktmpdir("fun-ci-installer-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new

      # When we run the installer
      FunCi::Installer.run(project_root: dir, stdout: stdout)

      # Then stdout should mention Ruby/Bundler
      assert_match(/ruby/i, stdout.string, "Should report detected language")
    end
  end

  def test_should_return_zero_on_success
    # Given a Ruby project directory
    Dir.mktmpdir("fun-ci-installer-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new

      # When we run the installer
      exit_code = FunCi::Installer.run(project_root: dir, stdout: stdout)

      # Then it should return success
      assert_equal 0, exit_code, "Should return 0 on success"
    end
  end
end

class TestInstallerUnknownProject < Minitest::Test
  def test_should_refuse_when_project_type_is_unknown
    # Given a project directory with no recognized marker files
    Dir.mktmpdir("fun-ci-installer-test") do |dir|
      File.write(File.join(dir, "README.md"), "# Hello\n")
      stdout = StringIO.new

      # When we run the installer
      exit_code = FunCi::Installer.run(project_root: dir, stdout: stdout)

      # Then it should refuse
      assert_equal 1, exit_code, "Should return 1 for unknown project type"
      assert_match(/could not detect|unknown/i, stdout.string, "Should explain the failure")
    end
  end
end

class TestInstallerAlreadyExists < Minitest::Test
  def test_should_skip_with_success_when_fun_ci_directory_already_exists
    # Given a project directory that already has .fun-ci/
    Dir.mktmpdir("fun-ci-installer-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      Dir.mkdir(File.join(dir, ".fun-ci"))
      stdout = StringIO.new

      # When we run the installer
      exit_code = FunCi::Installer.run(project_root: dir, stdout: stdout)

      # Then it should skip and return success
      assert_equal 0, exit_code, "Should return 0 when skipping (idempotent)"
      assert_match(/already exists/i, stdout.string, "Should explain the skip")
    end
  end
end

class TestInstallerMultiModuleGradle < Minitest::Test
  def test_should_scaffold_gradle_scripts_when_only_settings_gradle_kts_present
    # Given a multi-module Gradle project with settings.gradle.kts but no build.gradle.kts at root
    Dir.mktmpdir("fun-ci-installer-gradle-multi") do |dir|
      File.write(File.join(dir, "settings.gradle.kts"), "include(\":app\")\n")
      stdout = StringIO.new

      # When we run the installer
      exit_code = FunCi::Installer.run(project_root: dir, stdout: stdout)

      # Then it should succeed and create Gradle scripts
      assert_equal 0, exit_code, "Should return 0 on success"
      assert_match(/gradle/i, stdout.string, "Should report Gradle detection")
      lint_content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert_match(/gradlew/, lint_content, "Should create Gradle-based lint script")
    end
  end
end

class TestInstallerMavenNoLinter < Minitest::Test
  def test_should_use_default_lint_command_when_no_linter_plugin_found
    # Given a Maven project whose pom.xml has no recognized linter plugin
    Dir.mktmpdir("fun-ci-installer-no-linter") do |dir|
      File.write(File.join(dir, "pom.xml"), "<project></project>\n")
      stdout = StringIO.new
      pom_without_linter = "<project><artifactId>my-app</artifactId></project>"
      fake_pom_reader = ->(_path) { pom_without_linter }

      # When we run the installer with the pom_reader DI seam
      FunCi::Installer.run(project_root: dir, stdout: stdout, pom_reader: fake_pom_reader)

      # Then lint.sh should contain the default mvn verify command
      lint_content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert_match(/mvn verify -DskipTests/, lint_content, "Should use default lint command when no linter found")
    end
  end
end

class TestInstallerMavenLinterDetection < Minitest::Test
  def test_should_use_detected_linter_command_in_lint_script
    # Given a Maven project whose pom.xml contains detekt
    Dir.mktmpdir("fun-ci-installer-linter") do |dir|
      File.write(File.join(dir, "pom.xml"), "<project></project>\n")
      stdout = StringIO.new
      pom_with_detekt = <<~XML
        <project>
          <build><plugins>
            <plugin><artifactId>detekt-maven-plugin</artifactId></plugin>
          </plugins></build>
        </project>
      XML
      fake_pom_reader = ->(_path) { pom_with_detekt }

      # When we run the installer with the pom_reader DI seam
      FunCi::Installer.run(project_root: dir, stdout: stdout, pom_reader: fake_pom_reader)

      # Then lint.sh should contain the detected linter command
      lint_content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert_match(/mvn detekt:check/, lint_content, "Should use detected linter command")
      refute_match(/verify/, lint_content, "Should not contain the default mvn verify")
    end
  end
end
