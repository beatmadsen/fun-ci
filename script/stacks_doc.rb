# frozen_string_literal: true

# Writes docs/stacks.md from the code: the stacks `fun-ci init` detects, the
# scripts it writes for each, and the presets. Run it after changing any of
# them; test/policy/test_stacks_doc.rb fails until you do.
#
#   ruby script/stacks_doc.rb
require_relative "stacks_doc/page"

File.write(File.expand_path("../docs/stacks.md", __dir__), StacksDoc::Page.markdown)
