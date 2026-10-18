# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "tmpdir"
require "stringio"

# `fun-ci init` in a Node project: ESLint loads the packages the build
# installs, so it runs in the build, and only where the project configures it.
class TestInstallerEslint < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("fun-ci-installer-eslint")
    write_file("package.json", "{}")
  end

  def teardown = FileUtils.remove_entry(@dir)

  def test_should_run_eslint_in_the_build_of_a_node_project_that_configures_it
    write_file("eslint.config.js", "export default [];\n")
    install

    assert_equal "npm install && npx eslint .", script("build.sh")
  end

  def test_should_only_install_in_the_build_of_a_node_project_without_eslint
    install

    assert_equal "npm install", script("build.sh")
  end

  private

  def write_file(name, content) = File.write(File.join(@dir, name), content)
  def script(name) = File.read(File.join(@dir, ".fun-ci", name)).lines.last.chomp
  def install = FunCi::Setup::Installer.run(project_root: @dir, stdout: StringIO.new)
end
