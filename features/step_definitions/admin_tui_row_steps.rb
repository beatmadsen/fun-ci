# frozen_string_literal: true

# Then steps about which rows the board shows and what they contain.

Then("I should see a row with commit {string} and branch {string}") do |commit, branch|
  assert_match(/#{commit}/, @client.plain_output, "Should show commit #{commit}")
  assert_match(/#{branch}/, @client.plain_output, "Should show branch #{branch}")
end

Then("the row should show {string}") do |text|
  assert_match(/#{escaped(text)}/, @client.plain_output, "Board should show '#{text}'")
end

Then("the row should show status {string}") do |status|
  assert_match(/#{escaped(status)}/, @client.plain_output, "Board should show status '#{status}'")
end

Then("the first row should show commit {string}") do |commit|
  assert_match(/#{commit}/, commit_rows[0], "First row should show #{commit}")
end

Then("the second row should show commit {string}") do |commit|
  assert_match(/#{commit}/, commit_rows[1], "Second row should show #{commit}")
end

Then("the third row should show commit {string}") do |commit|
  assert_match(/#{commit}/, commit_rows[2], "Third row should show #{commit}")
end

Then("the row for commit {string} should show {string}") do |commit, text|
  line = @client.board_lines.find { |l| l.include?(commit) }
  assert line, "Should find a row with commit #{commit}"
  assert_match(/#{escaped(text)}/, line, "Row for #{commit} should show '#{text}'")
end

Then("the slow suite stage should show {string}") do |text|
  assert_match(/Slow #{escaped(text)}/, @client.plain_output, "Slow suite should show '#{text}'")
end

Then("the row should not show stage columns") do
  scheduled_line = @client.board_lines.find { |l| l.include?("Scheduled") }
  assert scheduled_line, "Should find scheduled row"
  refute_match(/Build/, scheduled_line, "Scheduled row should not show Build")
end

Then("the board should show {int} rows") do |count|
  assert_equal count, run_rows.length, "Board should show #{count} rows: #{run_rows.inspect}"
end

# The rows on screen are the newest runs, and no older commit appears anywhere.
Then("older runs beyond the visible area are simply not shown") do
  visible, older = @client.commits_newest_first.partition.with_index { |_, i| i < run_rows.length }
  assert_equal visible, run_rows.map { |row| row_commit(row) }, "The newest runs should fill the board"
  assert_empty(older.select { |commit| @client.plain_output.include?(commit) }, "Older runs should not show")
end

Then("the header should fill {int} columns") do |width|
  header = @client.header_line
  assert_equal width, header.length,
               "Header should be #{width} chars wide but was #{header.length}: #{header.inspect}"
end

Then("the board should show {string}") do |text|
  pattern = text.split(/\s+/).map { |w| Regexp.escape(w) }.join('\s+')
  assert_match(/#{pattern}/, @client.plain_output, "Board should show '#{text}'")
end

# Within: the loop is waiting no longer than that for its next refresh, which shows the run.
Then("the new run should appear on the board within {int} seconds") do |seconds|
  assert_operator @client.refresh_interval, :<=, seconds, "The loop should refresh within #{seconds}s"
  @client.refresh
  assert_match(/new1234/, @client.plain_output, "New run should appear on board")
end
