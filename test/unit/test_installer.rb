# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "tmpdir"
require "stringio"

module InstallerTestProject
  GEMFILE = "source 'https://rubygems.org'\n"

  def setup
    @dir = Dir.mktmpdir("fun-ci-installer-test")
    @stdout = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def write_file(name, content)
    File.write(File.join(@dir, name), content)
  end

  def install(**)
    FunCi::Setup::Installer.run(project_root: @dir, stdout: @stdout, **)
  end

  def lint_script
    File.read(File.join(@dir, ".fun-ci", "lint.sh"))
  end
end

class TestInstallerHappyPath < Minitest::Test
  include InstallerTestProject

  def test_should_report_detected_language_to_stdout
    write_file("Gemfile", GEMFILE)
    install
    assert_match(/ruby/i, @stdout.string, "Should report detected language")
  end

  def test_should_return_zero_on_success
    write_file("Gemfile", GEMFILE)
    assert_equal 0, install, "Should return 0 on success"
  end
end

class TestInstallerUnknownProject < Minitest::Test
  include InstallerTestProject

  def test_should_refuse_when_project_type_is_unknown
    write_file("README.md", "# Hello\n")
    assert_equal 1, install, "Should return 1 for unknown project type"
    assert_match(/could not detect|unknown/i, @stdout.string, "Should explain the failure")
  end
end

class TestInstallerAlreadyExists < Minitest::Test
  include InstallerTestProject

  def test_should_skip_with_success_when_fun_ci_directory_already_exists
    write_file("Gemfile", GEMFILE)
    Dir.mkdir(File.join(@dir, ".fun-ci"))
    assert_equal 0, install, "Should return 0 when skipping (idempotent)"
    assert_match(/already exists/i, @stdout.string, "Should explain the skip")
  end
end

class TestInstallerMultiModuleGradle < Minitest::Test
  include InstallerTestProject

  def test_should_scaffold_gradle_scripts_when_only_settings_gradle_kts_present
    write_file("settings.gradle.kts", "include(\":app\")\n")
    assert_equal 0, install, "Should return 0 on success"
    assert_match(/gradle/i, @stdout.string, "Should report Gradle detection")
    assert_match(/gradlew/, lint_script, "Should create Gradle-based lint script")
  end
end

class TestInstallerMavenLinter < Minitest::Test
  include InstallerTestProject

  POM_WITH_DETEKT = <<~XML
    <project>
      <build><plugins>
        <plugin><artifactId>detekt-maven-plugin</artifactId></plugin>
      </plugins></build>
    </project>
  XML

  def test_should_use_default_lint_command_when_no_linter_plugin_found
    write_file("pom.xml", "<project></project>\n")
    install(pom_reader: ->(_path) { "<project><artifactId>my-app</artifactId></project>" })
    assert_match(/mvn verify -DskipTests/, lint_script, "Should use default lint command when no linter found")
  end

  def test_should_use_detected_linter_command_in_lint_script
    write_file("pom.xml", "<project></project>\n")
    install(pom_reader: ->(_path) { POM_WITH_DETEKT })
    assert_match(/mvn detekt:check/, lint_script, "Should use detected linter command")
    refute_match(/verify/, lint_script, "Should not contain the default mvn verify")
  end
end
