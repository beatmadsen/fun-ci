# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../script/stacks_doc/page"

# docs/stacks.md says what fun-ci knows about each stack: how `fun-ci init`
# detects it, the scripts it writes, and when each preset runs. It is drawn
# from the code by script/stacks_doc.rb, so it can't fall behind it.
class TestStacksDoc < Minitest::Test
  DOC = File.expand_path("../../docs/stacks.md", __dir__)

  def test_should_say_what_the_code_says
    assert_equal StacksDoc::Page.markdown, File.read(DOC)
  end
end
