# frozen_string_literal: true

require_relative "../test_helper"

# `rake test` and the mutation lane load every test file into one process,
# where two files defining the same test class make one class of them, each
# with the other's setup, teardown and helpers. The narrower lanes load
# only one of the two, so there each passes.
class TestTestClassNames < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_no_two_test_files_define_the_same_test_class
    defined = Dir.glob("{test,contract}/**/*.rb", base: ROOT).flat_map { |path| test_classes(path) }
    repeated = defined.group_by(&:first).select { |_, where| where.size > 1 }

    assert_empty repeated
  end

  private

  def test_classes(path) = File.read(File.join(ROOT, path)).scan(/^class (Test\w+)/).map { |(name)| [name, path] }
end
