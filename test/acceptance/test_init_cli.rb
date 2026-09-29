# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "tmpdir"
require "stringio"

module InitCliProject
  SCRIPTS = %w[lint.sh build.sh fast.sh slow.sh].freeze

  def setup
    @dir = Dir.mktmpdir("fun-ci-init-test")
    @stdout = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  private

  def init_project_with(marker, content)
    File.write(File.join(@dir, marker), content)
    FunCi::Setup::Installer.run(project_root: @dir, stdout: @stdout)
  end

  def assert_all_scripts_executable
    SCRIPTS.each do |script|
      path = File.join(@dir, ".fun-ci", script)
      assert File.exist?(path), "#{script} should exist"
      assert File.executable?(path), "#{script} should be executable"
    end
  end

  def fast_script
    File.read(File.join(@dir, ".fun-ci", "fast.sh"))
  end
end

class TestInitCliRubyProject < Minitest::Test
  include InitCliProject

  def test_should_create_executable_scripts_for_ruby_project
    exit_code = init_project_with("Gemfile", "source 'https://rubygems.org'\n")
    assert_equal 0, exit_code, "Should return success exit code"
    assert_all_scripts_executable
    assert_match(/bundle exec/, fast_script, "Ruby template should use bundler")
  end
end

class TestInitCliGradleKotlinProject < Minitest::Test
  include InitCliProject

  def test_should_create_executable_scripts_for_gradle_kotlin_project
    exit_code = init_project_with("build.gradle.kts", "plugins { kotlin(\"jvm\") }\n")
    assert_equal 0, exit_code, "Should return success exit code"
    assert_all_scripts_executable
    assert_match(/gradlew/, fast_script, "Gradle template should use gradlew")
  end
end

class TestInitCliMavenProject < Minitest::Test
  include InitCliProject

  def test_should_create_executable_scripts_for_maven_project
    exit_code = init_project_with("pom.xml", "<project></project>\n")
    assert_equal 0, exit_code, "Should return success exit code"
    assert_all_scripts_executable
    assert_match(/mvn/, fast_script, "Maven template should use mvn")
  end
end

class TestInitCliUnknownProject < Minitest::Test
  include InitCliProject

  def test_should_refuse_when_project_type_is_unknown
    exit_code = init_project_with("README.md", "# Hello\n")
    assert_equal 1, exit_code, "Should return failure for unknown project type"
    assert_match(/could not detect|unknown/i, @stdout.string, "Should explain the failure")
  end
end

# Which stages run side by side (design.md, Stages side by side), said where
# the developer reads what init wrote.
class TestInitCliSideBySide < Minitest::Test
  include InitCliProject

  def test_should_say_which_stages_run_side_by_side
    init_project_with("go.mod", "module shop\n")

    assert_includes @stdout.string, "lint.sh runs beside build.sh, so it reads the source alone.\n" \
                                    "Then fast.sh runs beside slow.sh, both on what build.sh built"
  end
end
