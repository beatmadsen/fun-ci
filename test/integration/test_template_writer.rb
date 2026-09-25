# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/template_writer"
require "tmpdir"

# Writing a project's stage scripts. Which scripts they are is StageTemplates'.
class TestTemplateWriter < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("fun-ci-writer-test")
    FunCi::Setup::TemplateWriter.new(:jvm_maven, @dir, lint_override: "mvn detekt:check").write
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_write_each_stage_script_into_fun_ci
    written = Dir.children(fun_ci_dir).to_h { |name| [name, File.read(File.join(fun_ci_dir, name))] }

    assert_equal FunCi::Setup::StageTemplates.scripts(:jvm_maven, lint_override: "mvn detekt:check"), written
  end

  def test_should_make_every_stage_script_executable
    assert(Dir.children(fun_ci_dir).all? { |name| File.executable?(File.join(fun_ci_dir, name)) })
  end

  private

  def fun_ci_dir = File.join(@dir, ".fun-ci")
end
