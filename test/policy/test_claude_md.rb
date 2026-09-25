# frozen_string_literal: true

require_relative "../test_helper"

# AT-0.9: CLAUDE.md is Stack, Layout, Invariants and Gotchas, and every
# invariant names a test that exists to enforce it.
class TestClaudeMd < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  # Minitest and Cucumber, the Rust suite, and the binary contract lane.
  TEST_PATH = %r{`((?:test|features|renderer/tests|contract/binary)/[\w/.-]+\.(?:rb|feature|rs))`}

  def test_has_the_stack_layout_invariants_and_gotchas_sections
    assert_empty(%w[Stack Layout Invariants Gotchas] - sections.keys)
  end

  def test_every_invariant_names_the_test_that_enforces_it
    assert_empty(invariants.grep_v(TEST_PATH))
  end

  def test_every_test_an_invariant_names_exists
    named = invariants.flat_map { |invariant| invariant.scan(TEST_PATH).flatten }

    assert_empty(named.reject { |path| File.exist?(File.join(ROOT, path)) })
  end

  private

  def sections
    File.read(File.join(ROOT, "CLAUDE.md")).split(/^## /).drop(1).to_h { |part| part.split("\n", 2) }
  end

  def invariants = sections.fetch("Invariants", "").split(/^- /).drop(1)
end
