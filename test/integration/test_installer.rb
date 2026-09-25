# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "tmpdir"
require "stringio"

# `fun-ci init` in a project directory: what it detects from the files there
# and what it writes into .fun-ci/. The scripts themselves are StageTemplates'.
class TestInstaller < Minitest::Test
  GEMFILE = "source 'https://rubygems.org'\n"
  POM_WITH_DETEKT = "<project><build><plugins><plugin><artifactId>detekt-maven-plugin</artifactId>" \
                    "</plugin></plugins></build></project>"

  def setup
    @dir = Dir.mktmpdir("fun-ci-installer-test")
    @stdout = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_succeed_for_a_project_it_recognises
    write_file("Gemfile", GEMFILE)

    assert_equal 0, install
  end

  def test_should_say_what_kind_of_project_it_detected
    write_file("Gemfile", GEMFILE)
    install

    assert_includes @stdout.string, "Detected: ruby bundler"
  end

  def test_should_write_the_template_for_the_kind_of_project_it_detected
    write_file("Gemfile", GEMFILE)
    install

    assert_equal FunCi::Setup::StageTemplates.scripts(:ruby_bundler)["lint.sh"], lint_script
  end

  def test_should_recognise_a_multi_module_gradle_build_from_its_settings_file
    write_file("settings.gradle.kts", "include(\":app\")\n")
    install

    assert_equal FunCi::Setup::StageTemplates.scripts(:jvm_gradle_kotlin)["lint.sh"], lint_script
  end

  def test_should_lint_a_maven_project_with_the_linter_its_pom_configures
    write_file("pom.xml", POM_WITH_DETEKT)
    install

    assert_equal "#!/bin/sh\nmvn detekt:check\n", lint_script
  end

  def test_should_lint_a_maven_project_without_a_linter_plugin_the_default_way
    write_file("pom.xml", "<project><artifactId>my-app</artifactId></project>")
    install

    assert_equal FunCi::Setup::StageTemplates.scripts(:jvm_maven)["lint.sh"], lint_script
  end

  def test_should_fail_for_a_project_it_does_not_recognise
    write_file("README.md", "# Hello\n")

    assert_equal 1, install
  end

  def test_should_say_it_could_not_tell_what_kind_of_project_it_is
    write_file("README.md", "# Hello\n")
    install

    assert_includes @stdout.string, "Could not detect project type"
  end

  def test_should_succeed_without_writing_when_fun_ci_already_exists
    Dir.mkdir(File.join(@dir, ".fun-ci"))

    assert_equal 0, install
  end

  def test_should_leave_an_existing_fun_ci_directory_as_it_was
    write_file("Gemfile", GEMFILE)
    Dir.mkdir(File.join(@dir, ".fun-ci"))
    install

    assert_empty Dir.children(File.join(@dir, ".fun-ci"))
  end

  def test_should_say_it_did_nothing_because_fun_ci_already_exists
    Dir.mkdir(File.join(@dir, ".fun-ci"))
    install

    assert_includes @stdout.string, ".fun-ci/ already exists"
  end

  private

  def write_file(name, content) = File.write(File.join(@dir, name), content)
  def lint_script = File.read(File.join(@dir, ".fun-ci", "lint.sh"))

  def install = FunCi::Setup::Installer.run(project_root: @dir, stdout: @stdout)
end
