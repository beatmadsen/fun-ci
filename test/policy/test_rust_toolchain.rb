# frozen_string_literal: true

require_relative "../test_helper"

# Every machine and CI job builds the renderer with the same Rust, so clippy's
# verdict never depends on which stable happened to be installed. The root
# file points at the renderer's, which cargo-mutants copies with renderer/.
class TestRustToolchain < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  RENDERER = File.join(ROOT, "renderer/rust-toolchain.toml")

  def test_should_pin_the_renderer_to_one_rust_release
    assert_match(/^channel = "\d+\.\d+\.\d+"$/, File.read(RENDERER))
  end

  def test_should_use_the_renderer_s_toolchain_from_the_repository_root
    assert_equal File.realpath(RENDERER), File.realpath(File.join(ROOT, "rust-toolchain.toml"))
  end
end
