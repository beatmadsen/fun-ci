# frozen_string_literal: true

# Then steps about the header streak and the footer key bindings.

Then("the header should show {string}") do |text|
  assert_match(/#{escaped(text)}/, @client.plain_output, "Header should show '#{text}'")
end

Then("the header should not show a streak counter") do
  refute_match(/in a row/, @client.plain_output, "Should not show streak counter")
  refute_match(/Streak broken/, @client.plain_output, "Should not show streak broken")
end

Then("the header should update to show {string}") do |text|
  @client.open_tui
  assert_match(/#{escaped(text)}/, @client.plain_output, "Header should update to '#{text}'")
end

Then("the footer should show only {string}") do |text|
  lines = footer_lines
  assert_equal 1, lines.length, "Should have exactly one footer line"
  assert_match(/#{escaped(text)}/, lines[0], "Footer should show '#{text}'")
end

Then("the footer should not show {string} or {string}") do |text1, text2|
  footer = footer_lines.join(" ")
  refute_match(/#{escaped(text1)}/, footer, "Footer should not show '#{text1}'")
  refute_match(/#{escaped(text2)}/, footer, "Footer should not show '#{text2}'")
end
