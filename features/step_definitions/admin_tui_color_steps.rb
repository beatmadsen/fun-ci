# frozen_string_literal: true

# Then steps about the colours and emphasis the board draws with.

Then("the stage times should be displayed in green") do
  assert_match(/\e\[32m.*Build/, @client.raw_output, "Stage times should be green")
end

Then("the {string} status should be displayed in bold green") do |status|
  assert_match(/\e\[1;32m.*#{escaped(status)}/, @client.raw_output, "#{status} should be bold green")
end

Then("the failed stage should be displayed in bold red") do
  assert_match(/\e\[1;31m.*FAIL/, @client.raw_output, "Failed stage should be bold red")
end

Then("the {string} status should be displayed in bold red") do |status|
  assert_match(/\e\[1;31m.*#{escaped(status)}/, @client.raw_output, "#{status} should be bold red")
end

Then("the timed out stage should be displayed in bold yellow") do
  assert_match(/\e\[1;33m.*TIMEOUT/, @client.raw_output, "Timed out stage should be bold yellow")
end

Then("the {string} status should be displayed in bold yellow") do |status|
  assert_match(/\e\[1;33m.*#{escaped(status)}/, @client.raw_output, "#{status} should be bold yellow")
end

Then("the active stage should be displayed in cyan") do
  assert_match(/\e\[36m/, @client.raw_output, "Active stage should be cyan")
end

Then("the {string} status should be displayed in bold cyan") do |status|
  assert_match(/\e\[1;36m.*#{escaped(status)}/, @client.raw_output, "#{status} should be bold cyan")
end

Then("the slow suite stage showing {string} should be displayed in dim") do |text|
  assert_match(/\e\[2m.*Slow.*#{escaped(text)}/, @client.raw_output, "Unreached slow suite should be dim")
end

Then("the entire row should be displayed in dim") do
  assert_match(/\e\[2m/, @client.raw_output, "Scheduled row should be dim")
end

# Relative time reads either "Xm ago" or "just now"; both must be dim.
Then("the relative time should be displayed in dim") do
  has_dim_ago = @client.raw_output.match?(/\e\[2m[^\e]*ago/)
  has_dim_just_now = @client.raw_output.match?(/\e\[2m[^\e]*just now/)
  assert(has_dim_ago || has_dim_just_now, "Relative time should be dim")
end

Then("the {string} status should be displayed in dim") do |status|
  assert_match(/\e\[2m.*#{escaped(status)}/, @client.raw_output, "#{status} should be dim")
end

Then("the status {string} should be displayed in dim") do |status|
  assert_match(/\e\[2m.*#{escaped(status)}/, @client.raw_output, "#{status} should be dim")
end

Then("the header should show {string} in white on a charcoal background") do |text|
  assert_match(/\e\[48;5;236m/, @client.raw_output, "Header should have charcoal background")
  assert_match(/#{escaped(text)}/, @client.plain_output, "Header should show '#{text}'")
end

# The footer shows either the full key bindings or just "q quit"; either way it is dim.
Then("the footer showing key bindings should be displayed in dim") do
  has_dim_footer = @client.raw_output.match?(/\e\[2m[^\e]*q quit/)
  assert(has_dim_footer, "Footer should be dim")
end

Then("the slow suite should show {string} in dim") do |text|
  assert_match(/\e\[2m.*Slow.*#{escaped(text)}/, @client.raw_output, "Slow should be dim with '#{text}'")
end

Then("the streak text should be displayed in green") do
  assert_match(/\e\[32m.*in a row/, @client.raw_output, "Streak should be green")
end

Then("{string} should be displayed in default white, not red") do |text|
  assert_match(/#{escaped(text)}/, @client.plain_output, "Should show '#{text}'")
  refute_match(/\e\[1;31m.*#{escaped(text)}/, @client.raw_output, "#{text} should not be red")
end
