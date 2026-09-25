# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/renderer_lookup"

# AT-4.1: the renderer is FUN_CI_RENDERER's, else the one a platform gem
# bundles in libexec/, else the first on PATH; without one, the console says
# how to get one.
class TestRendererLookup < Minitest::Test
  BUNDLED = "/gem/libexec/fun-ci-renderer"

  def lookup(executables, env: {})
    runs = ->(path) { executables.include?(path) }
    FunCi::Console::RendererLookup.new(env: env, libexec: "/gem/libexec", executable: runs)
  end

  def test_should_use_the_renderer_fun_ci_renderer_names
    assert_equal "/opt/r", lookup(["/opt/r", BUNDLED], env: { "FUN_CI_RENDERER" => "/opt/r" }).path
  end

  def test_should_use_the_bundled_renderer_when_none_is_named
    assert_equal BUNDLED, lookup([BUNDLED, "/usr/bin/fun-ci-renderer"], env: { "PATH" => "/usr/bin" }).path
  end

  def test_should_use_the_first_renderer_on_the_path_when_none_is_bundled
    path = "/a:/b:/c"

    assert_equal "/b/fun-ci-renderer", lookup(%w[/b/fun-ci-renderer /c/fun-ci-renderer], env: { "PATH" => path }).path
  end

  def test_should_refuse_a_named_renderer_that_cannot_run
    error = assert_raises(FunCi::Console::RendererLookup::Missing) do
      lookup([BUNDLED], env: { "FUN_CI_RENDERER" => "/opt/gone" }).path
    end

    assert_includes error.message, "FUN_CI_RENDERER names /opt/gone"
  end

  def test_should_say_how_to_get_a_renderer_when_there_is_none
    error = assert_raises(FunCi::Console::RendererLookup::Missing) { lookup([], env: { "PATH" => "/usr/bin" }).path }

    assert_includes error.message, "cargo install fun-ci-renderer"
  end

  def test_should_look_on_no_path_when_path_is_unset
    assert_raises(FunCi::Console::RendererLookup::Missing) { lookup(["/fun-ci-renderer"]).path }
  end

  def test_should_skip_empty_path_entries
    assert_raises(FunCi::Console::RendererLookup::Missing) { lookup(["/fun-ci-renderer"], env: { "PATH" => ":/usr/bin" }).path }
  end
end
