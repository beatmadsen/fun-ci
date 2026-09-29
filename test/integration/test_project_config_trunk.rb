# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/project_config"
require "tmpdir"

# The trunk .fun-ci/config names, which never stops a pipeline (docs/trunk-conflicts.md, Which ref is the trunk).
class TestProjectConfigTrunk < Minitest::Test
  SCRIPTS = %w[lint.sh build.sh fast.sh slow.sh].freeze

  def setup
    @dir = Dir.mktmpdir
    FileUtils.mkdir_p(fun_ci_dir)
    SCRIPTS.each { |script| File.write(File.join(fun_ci_dir, script), "#!/bin/sh\n", perm: 0o755) }
  end

  def teardown = FileUtils.remove_entry(@dir)

  def test_should_name_no_trunk_when_nothing_says_which
    assert_nil config.trunk
  end

  def test_should_give_the_trunk_the_config_file_names
    File.write(File.join(fun_ci_dir, "config"), "trunk: origin/develop\n")

    assert_equal "origin/develop", config.trunk
  end

  def test_should_not_stop_a_pipeline_over_a_trunk_that_is_not_a_name
    File.write(File.join(fun_ci_dir, "config"), "trunk: [main]\n")

    assert_empty config.validate
  end

  def test_should_name_no_trunk_when_the_one_given_is_not_a_name
    File.write(File.join(fun_ci_dir, "config"), "trunk: [main]\n")

    assert_nil config.trunk
  end

  private

  def config = FunCi::Setup::ProjectConfig.new(@dir)
  def fun_ci_dir = File.join(@dir, ".fun-ci")
end
