# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/eslint_detection"

# The build init writes for a JavaScript project that configures ESLint: its
# install, then ESLint, which needs what the install put in place.
class TestEslintDetection < Minitest::Test
  def test_should_run_eslint_after_the_install_where_a_flat_config_is
    assert_equal "npm install && npx eslint .", build(:node_npm, %w[package.json eslint.config.js])
  end

  def test_should_run_eslint_where_an_older_config_file_is
    assert_equal "npm install && npx eslint .", build(:node_npm, %w[package.json .eslintrc.json])
  end

  def test_should_run_eslint_where_package_json_configures_it
    assert_equal "npm install && npx eslint .", build(:node_npm, %w[package.json], '{"eslintConfig": {}}')
  end

  def test_should_run_eslint_with_the_stack_s_own_runner
    assert_equal "pnpm install && pnpm exec eslint .", build(:node_pnpm, %w[package.json eslint.config.mjs])
  end

  def test_should_keep_the_template_s_build_where_nothing_configures_eslint
    assert_nil build(:node_npm, %w[package.json], '{"name": "app"}')
  end

  def test_should_keep_the_template_s_build_for_a_stack_eslint_is_no_part_of
    assert_nil build(:go, %w[go.mod eslint.config.js])
  end

  def test_should_keep_the_template_s_build_where_package_json_is_no_json
    assert_nil build(:node_npm, %w[package.json], "{")
  end

  private

  def build(stack, names, package_json = "{}") = FunCi::Setup::EslintDetection.build(stack, names, package_json)
end
