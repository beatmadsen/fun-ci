# frozen_string_literal: true

require_relative "../test_helper"

# The renderer crate as crates.io takes it (AT-4.3): keywords within its
# rules, which `cargo publish --dry-run` doesn't check, the oldest Rust it
# builds with, which the gems workflow builds it with, and only what a user
# builds, the licence among it.
class TestRendererCrate < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  MANIFEST = File.read(File.join(ROOT, "renderer/Cargo.toml"))
  KEYWORD = /\A[a-zA-Z][a-zA-Z0-9_+-]{0,19}\z/

  def test_should_have_at_most_five_keywords
    assert_operator list("keywords").size, :<=, 5
  end

  def test_should_have_keywords_crates_io_accepts
    assert_empty list("keywords").grep_v(KEYWORD)
  end

  def test_should_say_the_oldest_rust_it_builds_with
    assert_match(/^rust-version = "\d+\.\d+"$/, MANIFEST)
  end

  def test_should_tell_its_readers_the_oldest_rust_it_builds_with
    rust = MANIFEST[/^rust-version = "(.+)"$/, 1]

    assert_includes File.read(File.join(ROOT, "renderer/README.md")), "Rust #{rust} or newer"
  end

  def test_should_package_the_licence
    assert_includes list("include"), "LICENSE.txt"
  end

  def test_should_package_the_repository_s_licence
    assert_equal File.read(File.join(ROOT, "LICENSE.txt")), File.read(File.join(ROOT, "renderer/LICENSE.txt"))
  end

  private

  def list(key) = MANIFEST[/^#{key} = \[(.*)\]$/, 1].to_s.scan(/"([^"]+)"/).flatten
end
