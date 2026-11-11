# frozen_string_literal: true

require "prism"
require_relative "../test_helper"
require_relative "../../script/stacks_doc/names"

# The README's Getting started and the gem's description, which rubygems.org
# shows, each list the stacks `fun-ci init` writes scripts for. Both are prose,
# so nothing redraws them as script/stacks_doc.rb redraws docs/stacks.md: each
# must name every family of stack that page names.
class TestStackNamesInDocs < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  FAMILIES = StacksDoc::Names::STACKS.keys.map { StacksDoc::Names.family(_1) }.uniq.freeze

  def test_should_name_every_stack_family_in_the_readme
    assert_empty(FAMILIES.reject { readme_sentence.include?(_1) })
  end

  def test_should_name_every_stack_family_in_the_gem_description
    assert_empty(FAMILIES.reject { description_sentence.include?(_1) })
  end

  private

  def readme_sentence = sentence(File.read(File.join(ROOT, "README.md")), /^`fun-ci init` has templates for .*$/)

  # The description's last sentence, since `.NET` puts a full stop inside it.
  def description_sentence = sentence(description, /fun-ci init writes them for .*\z/m)

  def sentence(text, pattern) = text[pattern] || flunk("no sentence matches #{pattern.inspect}")

  def description
    tree = Prism.parse_file(File.join(ROOT, "fun_ci.gemspec")).value
    assignment = tree.breadth_first_search { |node| node.is_a?(Prism::CallNode) && node.name == :description= }
    assignment.arguments.arguments.first.parts.sum("", &:unescaped)
  end
end
