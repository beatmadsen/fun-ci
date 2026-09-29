# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/project_config"
require "tmpdir"

# The project's trunk settings are read from its .fun-ci/config; what each
# setting means is test/unit/test_settings_trunk.rb.
class TestProjectConfigTrunk < Minitest::Test
  def setup = @dir = Dir.mktmpdir
  def teardown = FileUtils.remove_entry(@dir)

  def test_should_give_the_trunk_the_project_s_config_file_names
    FileUtils.mkdir_p(File.join(@dir, ".fun-ci"))
    File.write(File.join(@dir, ".fun-ci", "config"), "trunk: origin/develop\n")

    assert_equal "origin/develop", FunCi::Setup::ProjectConfig.new(@dir).trunk
  end
end
