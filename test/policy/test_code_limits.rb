# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/instance_variable_count"

# The two coding limits RuboCop can't count as the project states them:
# 150 lines per file and 4 instance variables per class.
class TestCodeLimits < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  # §3.6 turns these into JSON and §5 deletes them.
  ANIMATION_DATA = %r{\Alib/fun_ci/animations/}

  def test_no_ruby_file_is_longer_than_150_lines
    long = ruby_files.grep_v(ANIMATION_DATA).select { |path| File.foreach(File.join(ROOT, path)).count > 150 }

    assert_empty long
  end

  def test_no_class_or_module_has_more_than_4_instance_variables
    crowded = ruby_files.flat_map { |path| crowded_scopes(path) }

    assert_empty crowded
  end

  def test_counts_instance_variables_per_class_leaving_nested_classes_to_themselves
    source = "class A\n  def x = (@a = @b = @c = 1)\n  class B\n    def y = (@d = @e = 1)\n  end\nend\n"

    assert_equal({ "A" => %i[@a @b @c], "B" => %i[@d @e] }, InstanceVariableCount.new(source).by_scope)
  end

  private

  def ruby_files
    Dir.glob("{lib,exe,test,contract}/**/*.rb", base: ROOT) + %w[Rakefile fun_ci.gemspec]
  end

  def crowded_scopes(path)
    InstanceVariableCount.new(File.read(File.join(ROOT, path))).by_scope
                         .select { |_scope, ivars| ivars.size > 4 }.map { |scope, ivars| "#{path} #{scope} #{ivars}" }
  end
end
