# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../renderer/tools/renderer_build"

# Whether the built renderer was built from renderer/src: `cargo package` (or
# publish) verifies the crate in the same target directory, and can leave
# target/debug/fun-ci-renderer built from its packaged copy, which cargo then
# counts as fresh however renderer/src changes.
class TestRendererBuild < Minitest::Test
  SRC = "/repo/renderer/src"

  def test_should_find_a_binary_built_from_the_source_fresh
    refute FunCi::RendererBuild.stale?("/repo/renderer/target/debug/fun-ci-renderer: #{SRC}/main.rs #{SRC}/lib.rs\n",
                                       SRC)
  end

  def test_should_find_a_binary_built_from_a_packaged_copy_stale
    assert FunCi::RendererBuild.stale?("/repo/renderer/target/debug/fun-ci-renderer: " \
                                       "/repo/renderer/target/package/fun-ci-renderer-2.0.0/src/main.rs\n", SRC)
  end

  def test_should_find_a_binary_never_built_fresh
    refute FunCi::RendererBuild.stale?(nil, SRC)
  end
end
